//
//  PacingApp.swift
//  Pacing
//
//  Created by 김은찬 on 6/25/26.
//

import SwiftUI
import FirebaseCore
import NaverThirdPartyLogin
import AVFoundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(KakaoSDKCommon)
import KakaoSDKCommon
import KakaoSDKAuth
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    private let naverDelegate = NaverLoginDelegate()
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        configureAudioSession()

        #if canImport(KakaoSDKCommon)
        KakaoSDK.initSDK(appKey: "73e4e7c46ea882a0d78a306b29553c17")
        #endif

        let naver = NaverThirdPartyLoginConnection.getSharedInstance()
        naver?.isNaverAppOauthEnable = true
        naver?.isInAppOauthEnable = true
        naver?.serviceUrlScheme = "naverPacing"
        naver?.consumerKey = "hxrh7_6fG3iRc6tKxOuY"
        naver?.consumerSecret = "l6C67zJ5g2"
        naver?.appName = "Pacing"
        naver?.delegate = naverDelegate

        return true
    }

    private func configureAudioSession() {
        // `.allowBluetoothHFP`는 `.playback` 카테고리와 함께 사용할 수 없어
        // `paramErr(-50)`로 오디오 세션 설정이 실패한다. 활성화는 메인 스레드를
        // 점유하지 않도록 백그라운드 큐에서 처리한다.
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
                try session.setActive(true)
            } catch {
                assertionFailure("오디오 세션을 설정하지 못했습니다: \(error.localizedDescription)")
            }
        }
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
                    NaverThirdPartyLoginConnection.getSharedInstance()?.receiveAccessToken(url)
                }
        }
    }
}
