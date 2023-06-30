//
//  AppDelegate.swift
//  DocGPT
//
//  Created by Edward McGuiggan on 5/3/23.
//

import UIKit
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "MainScene",
            sessionRole: .windowApplication
        )
        configuration.delegateClass = MainSceneDelegate.self
        
        return configuration
    }
}

final class MainSceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
    var window: UIWindow?
    var rootViewController: UIViewController?
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        window = windowScene.keyWindow
        rootViewController = window?.rootViewController
    }
}
