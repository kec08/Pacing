import Foundation

struct RunStatisticsSummary {
    let totalDistance: Double
    let totalDuration: Int
    let averagePace: Double
}

enum RunStatisticsCalculator {
    static func summary(
        from records: [RunRecord],
        where isIncluded: (RunRecord) -> Bool = { _ in true }
    ) -> RunStatisticsSummary {
        var totalDistance = 0.0
        var totalDuration = 0
        var validDistance = 0.0
        var validDuration = 0

        for record in records.lazy where isIncluded(record) {
            totalDistance += record.distance
            totalDuration += record.duration

            if record.isPaceValid {
                validDistance += record.distance
                validDuration += record.duration
            }
        }

        let averagePace = validDistance > 0
            ? Double(validDuration) / 60.0 / validDistance
            : 0

        return RunStatisticsSummary(
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            averagePace: averagePace
        )
    }
}
