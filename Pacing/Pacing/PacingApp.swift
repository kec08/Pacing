//
//  PacingApp.swift
//  Pacing
//
//  Created by 김은찬 on 6/25/26.
//

import SwiftUI

@main
struct PacingApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(appState)
        }
    }
}
