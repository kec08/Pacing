import CoreLocation
import Foundation

struct RunTrackedLocation {
    let location: CLLocation
    let cumulativeDistanceMeters: CLLocationDistance
}

struct RunKilometerMarker: Identifiable, Equatable {
    let kilometer: Int
    let coordinate: CLLocationCoordinate2D

    var id: Int { kilometer }

    static func == (lhs: RunKilometerMarker, rhs: RunKilometerMarker) -> Bool {
        lhs.kilometer == rhs.kilometer
            && abs(lhs.coordinate.latitude - rhs.coordinate.latitude) < 0.0000001
            && abs(lhs.coordinate.longitude - rhs.coordinate.longitude) < 0.0000001
    }
}

enum RunMetricsCalculator {
    static let kilometerMeters: CLLocationDistance = 1_000

    /// 누적 거리 기준의 km 경계를 각 위치 샘플 사이에서 선형 보간합니다.
    /// 한 샘플에서 여러 km 경계를 통과한 경우 모든 경계를 생성합니다.
    static func kilometerMarkers(
        from samples: [RunTrackedLocation],
        kilometerMeters: CLLocationDistance = Self.kilometerMeters
    ) -> [RunKilometerMarker] {
        guard kilometerMeters > 0, samples.count >= 2 else { return [] }

        var markers: [RunKilometerMarker] = []
        var nextBoundary = kilometerMeters

        for pair in zip(samples, samples.dropFirst()) {
            let previous = pair.0
            let current = pair.1
            guard current.cumulativeDistanceMeters > previous.cumulativeDistanceMeters else { continue }

            while nextBoundary <= current.cumulativeDistanceMeters {
                let segmentDistance = current.cumulativeDistanceMeters - previous.cumulativeDistanceMeters
                let progress = min(
                    max((nextBoundary - previous.cumulativeDistanceMeters) / segmentDistance, 0),
                    1
                )
                let coordinate = CLLocationCoordinate2D(
                    latitude: previous.location.coordinate.latitude
                        + (current.location.coordinate.latitude - previous.location.coordinate.latitude) * progress,
                    longitude: previous.location.coordinate.longitude
                        + (current.location.coordinate.longitude - previous.location.coordinate.longitude) * progress
                )
                markers.append(RunKilometerMarker(
                    kilometer: markers.count + 1,
                    coordinate: coordinate
                ))
                nextBoundary += kilometerMeters
            }
        }

        return markers
    }

    /// 유효한 수직 정확도를 가진 위치 샘플만 사용해 누적 상승 고도를 계산합니다.
    ///
    /// GPS 고도는 한 샘플만으로 크게 튈 수 있으므로 5개 샘플의 중앙값으로
    /// 완화한 뒤, 연속된 상승 추세가 확인된 변화만 누적합니다.
    static func elevationGain(
        from locations: [CLLocation],
        maximumVerticalAccuracy: CLLocationAccuracy = 10,
        minimumPositiveDelta: CLLocationDistance = 5,
        maximumPositiveDelta: CLLocationDistance = 12,
        minimumConsecutiveRises: Int = 2,
        maximumGainPerKilometer: CLLocationDistance = 30
    ) -> CLLocationDistance? {
        guard minimumConsecutiveRises > 0, maximumGainPerKilometer > 0 else { return nil }
        let valid = locations.filter {
            $0.verticalAccuracy > 0
                && $0.verticalAccuracy <= maximumVerticalAccuracy
                && $0.altitude.isFinite
        }.sorted { $0.timestamp < $1.timestamp }
        guard valid.count >= 2 else { return nil }

        let smoothedAltitudes = valid.indices.map { index in
            guard index > valid.startIndex, index < valid.index(before: valid.endIndex) else {
                return valid[index].altitude
            }

            let lowerBound = max(valid.startIndex, index - 2)
            let upperBound = min(valid.index(before: valid.endIndex), index + 2)
            return valid[lowerBound...upperBound]
                .map(\.altitude)
                .sorted()[((upperBound - lowerBound) / 2)]
        }

        var gain = 0.0
        var horizontalDistance = 0.0
        var previousAltitude = smoothedAltitudes[0]
        var pendingGain = 0.0
        var consecutiveRises = 0

        for (locationPair, altitude) in zip(zip(valid, valid.dropFirst()), smoothedAltitudes.dropFirst()) {
            horizontalDistance += locationPair.1.distance(from: locationPair.0)
            let delta = altitude - previousAltitude
            if delta >= minimumPositiveDelta, delta <= maximumPositiveDelta {
                pendingGain += delta
                consecutiveRises += 1
                if consecutiveRises >= minimumConsecutiveRises {
                    gain += pendingGain
                    pendingGain = 0
                    consecutiveRises = 0
                }
            } else if delta <= -minimumPositiveDelta {
                pendingGain = 0
                consecutiveRises = 0
            }
            previousAltitude = altitude
        }

        guard horizontalDistance > 0 else { return 0 }
        let maximumReasonableGain = horizontalDistance / 1_000.0 * maximumGainPerKilometer
        return min(gain, maximumReasonableGain)
    }
}
