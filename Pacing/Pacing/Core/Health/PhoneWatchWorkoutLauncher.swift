import Foundation
import HealthKit

@MainActor
final class PhoneWatchWorkoutLauncher {
    static let shared = PhoneWatchWorkoutLauncher()

    private let healthStore = HKHealthStore()

    private init() {}

    func launchRunningWorkout() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            NSLog("[Pacing] HealthKit을 사용할 수 없어 Watch 러닝을 시작하지 못했습니다.")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        do {
            try await healthStore.requestAuthorization(
                toShare: [HKObjectType.workoutType()],
                read: []
            )
            try await healthStore.startWatchApp(toHandle: configuration)
        } catch {
            NSLog("[Pacing] Watch 러닝 앱 실행 실패: %@", error.localizedDescription)
        }
    }
}
