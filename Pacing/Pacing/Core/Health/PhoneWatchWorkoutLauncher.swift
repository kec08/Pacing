import Foundation
import HealthKit

@MainActor
final class PhoneWatchWorkoutLauncher {
    static let shared = PhoneWatchWorkoutLauncher()

    private let healthStore = HKHealthStore()

    private init() {}

    func launchRunningWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        healthStore.startWatchApp(with: configuration) { success, error in
            if let error {
                NSLog("[Pacing] Watch 러닝 앱 실행 실패: %@", error.localizedDescription)
            } else if !success {
                NSLog("[Pacing] Watch 러닝 앱 실행 실패: 알 수 없는 오류")
            }
        }
    }
}
