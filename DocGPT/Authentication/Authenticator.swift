//
//  Authenticator.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 4/30/23.
//

import UIKit
import MSAL
import Foundation
import Security

struct Constants {
    static let tenantName = "docgptb2c.onmicrosoft.com"
    static let authorityHostName = "docgptb2c.b2clogin.com"
    static let clientID = "3493c6b7-3120-44c9-9650-fc5a60525146"
    static let signupOrSigninPolicy = "B2C_1_signupsignin"
    static let endpoint = "https://%@/tfp/%@/%@"
    static let scopes = ["https://docgptb2c.onmicrosoft.com/test/store_data"]
}

class Authenticator: ObservableObject {
    @Published var accessToken: String?
    @Published var userID: String?
    
    private var application: MSALPublicClientApplication!
    private var view: UIViewController

    init(view: UIViewController) {
        self.view = view
    }

    private func createPCAConfig(forPolicy policy: String) throws -> MSALPublicClientApplication {
        let authority = try getAuthority(forPolicy: policy)
        let pcaConfig = MSALPublicClientApplicationConfig(clientId: Constants.clientID, redirectUri: "msauth.com.tmcguiggan.DocGPT://auth", authority: authority)
        pcaConfig.knownAuthorities = [authority]
        return try MSALPublicClientApplication(configuration: pcaConfig)
    }

    func baseAuth(completionHandler: @escaping (String?, String?, String?) -> Void) {
        do {
            self.application = try createPCAConfig(forPolicy: Constants.signupOrSigninPolicy)
            refreshToken(completionHandler: completionHandler)
        } catch {
            print("Unable to create application: \(error)")
        }
    }

    private func handleResult(_ result: MSALResult?, _ error: Error?, completionHandler: @escaping (String?, String?, String?) -> Void) {
        guard let result = result else {
            print("Could not acquire token: \(error ?? "No error information" as Error)")
            return
        }
        
        accessToken = result.accessToken
        if let accountId = result.account.homeAccountId?.identifier,
           let idToken = result.idToken,
           let claims = parseIdToken(idToken),
           let givenName = claims["given_name"] as? String {
            userID = accountId
            completionHandler(accessToken, accountId, givenName)
        }
    }

    func authenticateUser(completionHandler: @escaping (String?, String?, String?) -> Void) {
        do {
            let authority = try getAuthority(forPolicy: Constants.signupOrSigninPolicy)
            let webViewParameters = MSALWebviewParameters(authPresentationViewController: view)
            let parameters = MSALInteractiveTokenParameters(scopes: Constants.scopes, webviewParameters: webViewParameters)
            parameters.promptType = .selectAccount
            parameters.authority = authority
            application.acquireToken(with: parameters) { (result, error) in
                self.handleResult(result, error, completionHandler: completionHandler)
            }
        } catch {
            print("Unable to create authority: \(error)")
        }
    }

    func parseIdToken(_ idToken: String) -> [String: Any]? {
        let parts = idToken.split(separator: ".")
        guard parts.count == 3, let jwtPayloadData = Data(base64Encoded: String(parts[1]), options: .ignoreUnknownCharacters) else { return nil }
        
        return (try? JSONSerialization.jsonObject(with: jwtPayloadData, options: [])) as? [String: Any]
    }

    func refreshToken(completionHandler: @escaping (String?, String?, String?) -> Void) {
        do {
            let authority = try getAuthority(forPolicy: Constants.signupOrSigninPolicy)
            guard let thisAccount = try getAccountByPolicy(withAccounts: application.allAccounts(), policy: Constants.signupOrSigninPolicy) else {
                authenticateUser(completionHandler: completionHandler)
                return
            }
            
            let parameters = MSALSilentTokenParameters(scopes: Constants.scopes, account: thisAccount)
            parameters.authority = authority
            application.acquireTokenSilent(with: parameters) { (result, error) in
                self.handleResult(result, error, completionHandler: completionHandler)
            }
        } catch {
            print("Error: \(error)")
        }
    }

    func signoutUser() {
        do {
            let thisAccount = try getAccountByPolicy(withAccounts: application.allAccounts(), policy: Constants.signupOrSigninPolicy)
            if let accountToRemove = thisAccount {
                try application.remove(accountToRemove)
                print("Signed out")
            } else {
                print("No account to sign out!")
            }
        } catch {
            print("Error signing out: \(error)")
        }
    }

    private func getAccountByPolicy(withAccounts accounts: [MSALAccount], policy: String) -> MSALAccount? {
        return accounts.first(where: { $0.homeAccountId?.objectId?.hasSuffix(policy.lowercased()) == true })
    }

    private func getAuthority(forPolicy policy: String) throws -> MSALB2CAuthority {
        guard let authorityURL = URL(string: String(format: Constants.endpoint, Constants.authorityHostName, Constants.tenantName, policy)) else {
            throw NSError(domain: "SomeDomain", code: 1, userInfo: ["errorDescription": "Unable to create authority URL!"])
        }
        return try MSALB2CAuthority(url: authorityURL)
    }
}
