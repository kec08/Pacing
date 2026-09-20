//
//  Pacing_WatchApp.swift
//  Pacing Watch Watch App
//
//  Created by 김은찬 on 9/17/26.
//

import SwiftUI
import HealthKit
import WatchKit

@MainActor
final class WatchWorkoutLaunchStore {
    static let shared = WatchWorkoutLaunchStore()
    private var pendingConfiguration: HKWorkoutConfiguration?

    func store(_ configuration: HKWorkoutConfiguration) {
        pendingConfiguration = configuration
        NotificationCenter.default.post(name: .phoneStartedRunning, object: configuration)
    }

    func takePendingConfiguration() -> HKWorkoutConfiguration? {
        defer { pendingConfiguration = nil }
        return pendingConfiguration
    }
}

final class WatchApplicationDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            WatchWorkoutLaunchStore.shared.store(workoutConfiguration)
        }
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
