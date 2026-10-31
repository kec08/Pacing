import Combine
import Foundation
import HealthKit

@MainActor
final class HealthKitWatchWorkoutRepository: NSObject, ObservableObject {
    @Published private(set) var liveMetrics = WatchRunMetrics.empty
    @Published private(set) var sessionError: WatchRunError?

    private let healthStore: HKHealthStore
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    var hasActiveWorkoutSession: Bool { workoutSession != nil }

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func start() async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        try await start(configuration: configuration, startDate: .now)
    }

    func start(configuration: HKWorkoutConfiguration, startDate: Date) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WatchRunError.healthDataUnavailable
        }

        do {
            try await requestAuthorizationIfNeeded()
        } catch let error as WatchRunError {
            throw error
        } catch {
            throw WatchRunError.healthAuthorizationRequired
        }

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self

            workoutSession = session
            workoutBuilder = builder
            liveMetrics = .empty
            sessionError = nil

            session.startActivity(with: startDate)
            try await beginCollection(builder, startDate: startDate)
            Task {
                do {
                    try await session.startMirroringToCompanionDevice()
                } catch {
                    NSLog("[Pacing] Watch 운동 미러링 연결 실패: %@", error.localizedDescription)
                }
            }
        } catch {
            workoutSession?.end()
            workoutSession = nil
            workoutBuilder = nil
            throw WatchRunError.sessionStartFailed
        }
    }

    func pause() {
        workoutSession?.pause()
    }

    func resume() {
        workoutSession?.resume()
    }

    func end() async throws {
        guard let workoutSession, let workoutBuilder else {
            throw WatchRunError.sessionUnavailable
        }

        workoutSession.end()
        do {
            try await endCollection(workoutBuilder)
            if let workout = try await finishWorkout(workoutBuilder) {
                if let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                    .sumQuantity()?.doubleValue(for: .meter()), distance.isFinite, distance > 0 {
                    liveMetrics.distanceMeters = max(liveMetrics.distanceMeters, distance)
                }
                liveMetrics.elapsed = workout.duration
            }
            self.workoutSession = nil
            self.workoutBuilder = nil
        } catch {
            self.workoutSession = nil
            self.workoutBuilder = nil
            throw WatchRunError.sessionEndFailed
        }
    }

    private func requestAuthorizationIfNeeded() async throws {
        let shareStatus = healthStore.authorizationStatus(for: .workoutType())
        guard shareStatus != .sharingDenied else {
            throw WatchRunError.healthAuthorizationRequired
        }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ]
        let shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: WatchRunError.healthAuthorizationRequired)
                }
            }
        }
    }

    private func beginCollection(_ builder: HKLiveWorkoutBuilder, startDate: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: startDate) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: WatchRunError.sessionStartFailed)
                }
            }
        }
    }

    private func endCollection(_ builder: HKLiveWorkoutBuilder) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: .now) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: WatchRunError.sessionEndFailed)
                }
            }
        }
    }

    private func finishWorkout(_ builder: HKLiveWorkoutBuilder) async throws -> HKWorkout? {
        try await withCheckedThrowingContinuation { continuation in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: workout)
                }
            }
        }
    }

    private func refreshLiveMetrics() {
        guard let workoutBuilder else { return }
        let heartRate = quantityValue(for: .heartRate, unit: .count().unitDivided(by: .minute()), builder: workoutBuilder)
        let energy = quantityValue(for: .activeEnergyBurned, unit: .kilocalorie(), builder: workoutBuilder)
        let distanceStatistics = workoutBuilder.statistics(for: HKQuantityType(.distanceWalkingRunning))
        let distance = distanceStatistics?.sumQuantity()?.doubleValue(for: .meter())
            ?? liveMetrics.distanceMeters

        liveMetrics.heartRateBeatsPerMinute = heartRate
        liveMetrics.activeEnergyKilocalories = energy
        liveMetrics.distanceMeters = max(liveMetrics.distanceMeters, distance)
    }

    private func quantityValue(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        builder: HKLiveWorkoutBuilder
    ) -> Double? {
        builder.statistics(for: HKQuantityType(identifier))?.mostRecentQuantity()?.doubleValue(for: unit)
    }
}

extension HealthKitWatchWorkoutRepository: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        NSLog("[Pacing] Watch 운동 세션 실패: %@", error.localizedDescription)
        Task { @MainActor [weak self] in
            guard let self, self.workoutSession === workoutSession else { return }
            self.workoutSession = nil
            self.workoutBuilder = nil
            self.sessionError = .sessionUnavailable
        }
    }
}

extension HealthKitWatchWorkoutRepository: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor [weak self] in
            self?.refreshLiveMetrics()
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
