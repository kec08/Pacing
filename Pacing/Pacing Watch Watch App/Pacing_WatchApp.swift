//
//  Pacing_WatchApp.swift
//  Pacing Watch Watch App
//
//  Created by 김은찬 on 9/17/26.
//

import SwiftUI
import HealthKit
import WatchKit

final class WatchApplicationDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            // iPhone에서 백그라운드로 깨운 직후 UI가 아직 만들어지지 않았더라도
            // 운동 세션을 즉시 시작해야 Watch가 러닝 화면을 전면에 유지한다.
            WatchAppViewModel.shared.startWorkoutFromPhone(configuration: workoutConfiguration)
        }
    }
}

@main
struct Pacing_Watch_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WatchApplicationDelegate.self) private var applicationDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(PacingWatchTheme.main500)
                .preferredColorScheme(.dark)
        }
    }
}
