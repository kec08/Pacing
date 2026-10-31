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
do {
    try await healthStore.startWatchApp(toHandle: configuration)
    NSLog("[Pacing] Watch 러닝 앱 자동 실행 요청 완료")
} catch {
    // WatchConnectivity가 잠깐 준비 중인 경우 한 번만 재시도해 앱 자동 실행 누락을 줄인다.
    try? await Task.sleep(nanoseconds: 500_000_000)
    try await healthStore.startWatchApp(toHandle: configuration)
    NSLog("[Pacing] Watch 러닝 앱 자동 실행 재시도 완료")
}
        } catch {
            NSLog("[Pacing] Watch 러닝 앱 실행 실패: %@", error.localizedDescription)
        }
    }
}
