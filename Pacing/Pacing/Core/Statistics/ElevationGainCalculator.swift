import Foundation

struct ElevationSample: Equatable {
    let timestamp: Date
    let altitudeMeters: Double
}

enum ElevationGainCalculator {
    /// 상대 기압 고도의 작은 압력 노이즈를 제거하기 위한 최소 확정 상승/하강 폭입니다.
    static let minimumConfirmedClimbMeters = 3.0
    static let minimumDescentForNewBaselineMeters = 2.0

    /// 상대 고도에서 확인된 저점-정점 상승 구간만 한 번씩 누적합니다.
    /// GPS 절대 고도는 이 계산기에 전달하지 않습니다.
    static func gain(from samples: [ElevationSample]) -> Double? {
        let valid = samples
            .filter { $0.altitudeMeters.isFinite }
            .sorted { $0.timestamp < $1.timestamp }
        guard valid.count >= 2 else { return nil }

        let smoothedAltitudes = smoothed(valid.map(\.altitudeMeters))
        var gain = 0.0
        var valley = smoothedAltitudes[0]
        var peak = valley

        for altitude in smoothedAltitudes.dropFirst() {
            if altitude > peak {
                peak = altitude
                continue
            }

            guard peak - altitude >= minimumDescentForNewBaselineMeters else { continue }
            if peak - valley >= minimumConfirmedClimbMeters {
                gain += peak - valley
            }
            valley = altitude
            peak = altitude
        }

        if peak - valley >= minimumConfirmedClimbMeters {
            gain += peak - valley
        }

        return gain
    }

    private static func smoothed(_ values: [Double]) -> [Double] {
        values.indices.map { index in
            let lowerBound = max(values.startIndex, index - 2)
            let upperBound = min(values.index(before: values.endIndex), index + 2)
            let window = values[lowerBound...upperBound].sorted()
            return window[window.index(window.startIndex, offsetBy: window.count / 2)]
        }
    }
}
