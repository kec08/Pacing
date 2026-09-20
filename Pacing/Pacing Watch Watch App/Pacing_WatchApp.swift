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
        NotificationCenter.default.post(
            name: .phoneStartedRunning,
            object: workoutConfiguration
        )
    }
}

extension Notification.Name {
    static let phoneStartedRunning = Notification.Name("phoneStartedRunning")
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
