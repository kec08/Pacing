import Foundation
import HealthKit

protocol HeartRateRepository {
    func requestReadAuthorization() async -> Bool
    func averageHeartRate(from startDate: Date, to endDate: Date) async -> Double?
}

final class HealthKitHeartRateRepository: HeartRateRepository {
    private let healthStore: HKHealthStore?

    init(healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil) {
        self.healthStore = healthStore
    }

    func requestReadAuthorization() async -> Bool {
        guard let healthStore else { return false }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [heartRateType])
            return true
        } catch {
            return false
        }
    }

    func averageHeartRate(from startDate: Date, to endDate: Date) async -> Double? {
        guard let healthStore,
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              startDate < endDate
        else { return nil }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { [weak self] _, samples, _ in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                let heartRateSamples = (samples as? [HKQuantitySample] ?? [])
                    .filter { self.isValidHeartRateSample($0) }

                // Apple Watch 샘플을 우선 사용하고, Watch가 식별되지 않는 환경에서는
                // HealthKit의 유효 심박수 샘플을 fallback으로 사용한다.
                let watchSamples = heartRateSamples.filter { self.isAppleWatchSample($0) }
                let selectedSamples = watchSamples.isEmpty ? heartRateSamples : watchSamples
                guard !selectedSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let average = selectedSamples
                    .map { $0.quantity.doubleValue(for: unit) }
                    .reduce(0, +) / Double(selectedSamples.count)
                continuation.resume(returning: average.isFinite ? average : nil)
            }
            healthStore.execute(query)
        }
    }

    private func isValidHeartRateSample(_ sample: HKQuantitySample) -> Bool {
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let bpm = sample.quantity.doubleValue(for: unit)
        return bpm.isFinite && (30...240).contains(bpm)
    }

    private func isAppleWatchSample(_ sample: HKQuantitySample) -> Bool {
        let deviceName = sample.device?.name ?? ""
        let deviceModel = sample.device?.model ?? ""
        let sourceName = sample.sourceRevision.source.name
        return [deviceName, deviceModel, sourceName].contains {
            $0.localizedCaseInsensitiveContains("watch")
        }
    }
}
