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

    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject var vm = ContentViewModel(api: ChatGPTAPI(apiKey: "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"))
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView(vm: vm)
                    .preferredColorScheme(.dark)
            }
            .preferredColorScheme(.dark)
        }
    }
}
