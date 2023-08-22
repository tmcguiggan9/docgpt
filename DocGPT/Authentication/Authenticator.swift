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

class Authenticator: ObservableObject {
    
    @Published var accessToken: String?
    @Published var userID: String?
    let kTenantName = "docgptb2c.onmicrosoft.com"
    let kAuthorityHostName = "docgptb2c.b2clogin.com"
    let kClientID = "3493c6b7-3120-44c9-9650-fc5a60525146"
    let kSignupOrSigninPolicy = "B2C_1_signupsignin"
    let kEditProfilePolicy = "b2c_1_edit_profile"
    let kResetPasswordPolicy = "b2c_1_reset"
    let kGraphURI = "https://doc-gpt-app.azurewebsites.net/your-route"
    let kScopes: [String] = ["https://docgptb2c.onmicrosoft.com/test/store_data"]
    let kEndpoint = "https://%@/tfp/%@/%@"
    
    var application: MSALPublicClientApplication!
    
    var view: UIViewController
    
    init(view: UIViewController) {
        self.view = view
    }
    
    func baseAuth(completionHandler: @escaping (String?, String?, String?) -> Void) {
        do {
            let siginPolicyAuthority = try self.getAuthority(forPolicy: self.kSignupOrSigninPolicy)
            
            let pcaConfig = MSALPublicClientApplicationConfig(clientId: kClientID, redirectUri: "msauth.com.tmcguiggan.DocGPT://auth", authority: siginPolicyAuthority)
            pcaConfig.knownAuthorities = [siginPolicyAuthority]
            self.application = try MSALPublicClientApplication(configuration: pcaConfig)
        } catch {
            print("Unable to create application \(error)")
        }
        refreshToken { token, userID, givenName  in
            completionHandler(token, userID, givenName)
        }
    }
    
    func authenticateUser(completionHandler: @escaping (String?, String?, String?) -> Void) {
        do {
            let authority = try self.getAuthority(forPolicy: self.kSignupOrSigninPolicy)
            let webViewParameters = MSALWebviewParameters(authPresentationViewController: view)
            let parameters = MSALInteractiveTokenParameters(scopes: kScopes, webviewParameters: webViewParameters)
            parameters.promptType = .selectAccount
            parameters.authority = authority
            application.acquireToken(with: parameters) { (result, error) in
                
                guard let result = result else {
                    print("Could not acquire token: \(error ?? "No error informarion" as Error)")
                    return
                }
                
                self.accessToken = result.accessToken
                let accessToken = result.accessToken
                print("Access token is \(accessToken )")
                
                if let accountId = result.account.homeAccountId?.identifier, let idToken = result.idToken,
                   let claims = self.parseIdToken(idToken),
                       let givenName = claims["given_name"] as? String {
                    print("User ID is \(accountId)")
                    completionHandler(accessToken, accountId, givenName)
                }
                
                
                if let idToken = result.idToken,
                   let claims = self.parseIdToken(idToken),
                       let givenName = claims["given_name"] as? String {
                        print("GivenName is \(givenName)")
                    }
            }
        } catch {
            print("Unable to create authority \(error)")
        }
    }
    
    
    func parseIdToken(_ idToken: String) -> [String: Any]? {
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        let jwtPayloadData = Data(base64Encoded: String(parts[1]), options: .ignoreUnknownCharacters)
        guard let data = jwtPayloadData else { return nil }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            print("Error parsing idToken: \(error)")
            return nil
        }
    }
    
    
    func refreshToken(completionHandler: @escaping (String?, String?, String?) -> Void) {
        
        do {
            let authority = try self.getAuthority(forPolicy: self.kSignupOrSigninPolicy)
            
            guard let thisAccount = try self.getAccountByPolicy(withAccounts: application.allAccounts(), policy: kSignupOrSigninPolicy) else {
                authenticateUser { token, userID, givenName  in
                    completionHandler(token, userID, givenName)
                }
                return
            }
            
            let parameters = MSALSilentTokenParameters(scopes: kScopes, account:thisAccount)
            parameters.authority = authority
            self.application.acquireTokenSilent(with: parameters) { (result, error) in
                if let error = error {
                    
                    let nsError = error as NSError
                    
                    if (nsError.domain == MSALErrorDomain) {
                        
                        if (nsError.code == MSALError.interactionRequired.rawValue) {
                            let webviewParameters = MSALWebviewParameters(authPresentationViewController: self.view)
                            let parameters = MSALInteractiveTokenParameters(scopes: self.kScopes, webviewParameters: webviewParameters)
                            parameters.account = thisAccount
                            
                            DispatchQueue.main.async {
                                self.application.acquireToken(with: parameters) { (result, error) in
                                    
                                    guard let result = result else {
                                        print("Could not acquire new token: \(error ?? "No error informarion" as Error)")
                                        return
                                    }
                                    
                                    
                                    if let accountID = result.account.homeAccountId?.identifier,
                                    let idToken = result.idToken,
                                    let claims = self.parseIdToken(idToken),
                                       let givenName = claims["given_name"] as? String {
                                        completionHandler(result.accessToken, accountID, givenName)
                                    }
                                    
                                }
                            }
                            return
                        }
                    }
                    
                    print("Could not acquire token: \(error)")
                    return
                }
                guard let result = result else {
                    
                    print("Could not acquire token: No result returned")
                    return
                }
                
                self.accessToken = result.accessToken
                let accessToken = result.accessToken
                
                if let accountId = result.account.homeAccountId?.identifier, let idToken = result.idToken,
                   let claims = self.parseIdToken(idToken),
                       let givenName = claims["given_name"] as? String {
                    self.userID = accountId
                    completionHandler(accessToken, accountId, givenName)
                }
                
                if let idToken = result.idToken,
                   let claims = self.parseIdToken(idToken),
                       let givenName = claims["given_name"] as? String {
                        print("GivenName is \(givenName)")
                    }
                
                print("Refreshing token silently")
            }
        } catch {
            print("Unable to construct parameters before calling acquire token \(error)")
        }
    }
    
    
    
    func signoutUser() {
        do {
            
            let thisAccount = try self.getAccountByPolicy(withAccounts: application.allAccounts(), policy: kSignupOrSigninPolicy)
            
            if let accountToRemove = thisAccount {
                try application.remove(accountToRemove)
            } else {
                print("There is no account to signing out!")
            }
            
            
            
            print("Signed out")
            
        } catch  {
            print("Received error signing out: \(error)")
        }
    }
    
    
    func getAccountByPolicy (withAccounts accounts: [MSALAccount], policy: String) throws -> MSALAccount? {
        
        for account in accounts {
            // This is a single account sample, so we only check the suffic part of the object id,
            // where object id is in the form of <object id>-<policy>.
            // For multi-account apps, the whole object id needs to be checked.
            if let homeAccountId = account.homeAccountId, let objectId = homeAccountId.objectId {
                if objectId.hasSuffix(policy.lowercased()) {
                    return account
                }
            }
        }
        return nil
    }
    
    func getAuthority(forPolicy policy: String) throws -> MSALB2CAuthority {
        guard let authorityURL = URL(string: String(format: self.kEndpoint, self.kAuthorityHostName, self.kTenantName, policy)) else {
            throw NSError(domain: "SomeDomain",
                          code: 1,
                          userInfo: ["errorDescription": "Unable to create authority URL!"])
        }
        return try MSALB2CAuthority(url: authorityURL)
    }
}
