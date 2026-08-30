import Foundation

struct CadenceSample: Equatable {
    let timestamp: Date
    let cumulativeSteps: Int
    let currentCadenceStepsPerSecond: Double?

    init(
        timestamp: Date,
        cumulativeSteps: Int,
        currentCadenceStepsPerSecond: Double?
    ) {
        self.timestamp = timestamp
        self.cumulativeSteps = cumulativeSteps
        self.currentCadenceStepsPerSecond = currentCadenceStepsPerSecond
    }
}

struct CadenceAccumulator {
    static let maximumCadenceStepsPerMinute = 300.0

    private(set) var totalSteps = 0
    private(set) var activeDuration: TimeInterval = 0

    private var previousSample: CadenceSample?
    private var segmentStartDate: Date?

    init(segmentStartDate: Date? = nil) {
        self.segmentStartDate = segmentStartDate
    }

    mutating func reset() {
        totalSteps = 0
        activeDuration = 0
        previousSample = nil
        segmentStartDate = nil
    }

    mutating func resetBaseline(at startDate: Date? = nil) {
        totalSteps = 0
        activeDuration = 0
        previousSample = nil
        segmentStartDate = startDate
    }

    /// 샘플 간 누적 걸음 수와 시간만 합산합니다.
    /// 현재 케이던스가 nil이어도 누적 걸음 수와 시각이 유효하면 평균 계산에는 사용할 수 있습니다.
    mutating func ingest(_ sample: CadenceSample) -> Double? {
        guard sample.cumulativeSteps >= 0, sample.timestamp <= Date.distantFuture else {
            return nil
        }

        guard let previousSample else {
            if let segmentStartDate,
               sample.timestamp >= segmentStartDate {
                totalSteps += sample.cumulativeSteps
                activeDuration += sample.timestamp.timeIntervalSince(segmentStartDate)
            }
            self.previousSample = sample
            return validatedCurrentCadence(from: sample)
        }

        let interval = sample.timestamp.timeIntervalSince(previousSample.timestamp)
        let stepDelta = sample.cumulativeSteps - previousSample.cumulativeSteps

        guard interval > 0,
              stepDelta >= 0
        else {
            if stepDelta < 0 {
                totalSteps = 0
                activeDuration = 0
            }
            self.previousSample = sample
            return validatedCurrentCadence(from: sample)
        }

        totalSteps += stepDelta
        activeDuration += interval
        self.previousSample = sample
        return validatedCurrentCadence(from: sample)
    }

    var averageStepsPerMinute: Double? {
        guard totalSteps > 0, activeDuration > 0 else { return nil }
        let average = Double(totalSteps) / activeDuration * 60
        guard average.isFinite, average > 0, average <= Self.maximumCadenceStepsPerMinute else {
            return nil
        }
        return average
    }

    private func validatedCurrentCadence(from sample: CadenceSample) -> Double? {
        guard let current = sample.currentCadenceStepsPerSecond,
              current.isFinite,
              current > 0
        else { return nil }

        let stepsPerMinute = current * 60
        guard stepsPerMinute <= Self.maximumCadenceStepsPerMinute else { return nil }
        return stepsPerMinute
    }
}
