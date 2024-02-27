//
//  DocGPTApp.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 4/30/23.
//

import SwiftUI
import MSAL

private struct MSALPublicClientApplicationKey: EnvironmentKey {
    static var defaultValue: MSALPublicClientApplication = .init()
}

extension EnvironmentValues {
    var msalApplication: MSALPublicClientApplication {
        get { self[MSALPublicClientApplicationKey.self] }
        set { self[MSALPublicClientApplicationKey.self] = newValue }
    }
}


@main
struct DocGPTApp: App {
    
    init() {
        setupNavigationBarAppearance()
    }

    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SplashScreenView()
                    .preferredColorScheme(.dark)
            }
            .preferredColorScheme(.dark)
        }
    }
    
    func setupNavigationBarAppearance() {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground // Or any color you prefer
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label] // Adjust title color
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance // Optional for smaller nav bars
        }
}
