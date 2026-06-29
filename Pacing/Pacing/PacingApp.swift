//
//  PacingApp.swift
//  Pacing
//
//  Created by 김은찬 on 6/25/26.
//

import SwiftUI
import FirebaseCore
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(KakaoSDKCommon)
import KakaoSDKCommon
import KakaoSDKAuth
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        #if canImport(KakaoSDKCommon)
        KakaoSDK.initSDK(appKey: "73e4e7c46ea882a0d78a306b29553c17")
        #endif
        return true
    }
}

@main
struct PacingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    GIDSignIn.sharedInstance.handle(url)
                    #endif
                    #if canImport(KakaoSDKAuth)
                    _ = AuthController.handleOpenUrl(url: url)
                    #endif
                }
        }
    }
}
