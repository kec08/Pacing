import CoreLocation

struct RunRouteKilometerMarker: Identifiable {
    let kilometer: Int
    let coordinate: CLLocationCoordinate2D

    var id: Int { kilometer }
}

/// 경로 좌표의 누적 거리로 km 지점을 찾는다.
enum RunRouteKilometerMarkers {
    /// 이 거리(km)를 넘는 기록은 라벨이 겹치지 않게 2km 간격으로 표시한다.
    static let sparseIntervalThresholdKilometers: Double = 15

    /// - Parameters:
    ///   - recordedDistanceKilometers: 기록된 거리. Watch 거리처럼 GPS 경로 길이와 다를 수 있어
    ///     경로 길이를 이 거리에 비례해 맞춘다. 그래서 라벨 수가 구간 표의 행 수와 같다.
    ///   - endpointClearanceMeters: 도착 지점과 이 거리 안이면 도착 핀과 겹치므로 라벨을 생략한다.
    static func markers(
        for coordinates: [CLLocationCoordinate2D],
        recordedDistanceKilometers: Double,
        endpointClearanceMeters: Double = 50
    ) -> [RunRouteKilometerMarker] {
        guard coordinates.count >= 2,
              recordedDistanceKilometers.isFinite,
              recordedDistanceKilometers >= 1 else { return [] }

        var cumulativeMeters: [Double] = [0]
        cumulativeMeters.reserveCapacity(coordinates.count)
        for index in 1..<coordinates.count {
            let previous = coordinates[index - 1]
            let current = coordinates[index]
            let meters = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
                .distance(from: CLLocation(latitude: current.latitude, longitude: current.longitude))
            cumulativeMeters.append(cumulativeMeters[index - 1] + (meters.isFinite ? meters : 0))
        }

        let routeMeters = cumulativeMeters[cumulativeMeters.count - 1]
        guard routeMeters > 0 else { return [] }

        // 기록 거리 1m가 경로 위에서 몇 m인지.
        let routeMetersPerRecordedMeter = routeMeters / (recordedDistanceKilometers * 1_000)
        let completedKilometers = Int(recordedDistanceKilometers.rounded(.down))
        let interval = recordedDistanceKilometers > sparseIntervalThresholdKilometers ? 2 : 1

        var markers: [RunRouteKilometerMarker] = []
        var segmentEnd = 1
        for kilometer in stride(from: interval, through: completedKilometers, by: interval) {
            let target = Double(kilometer) * 1_000 * routeMetersPerRecordedMeter
            guard routeMeters - target >= endpointClearanceMeters * routeMetersPerRecordedMeter else { break }

            while segmentEnd < cumulativeMeters.count - 1, cumulativeMeters[segmentEnd] < target {
                segmentEnd += 1
            }
            let startMeters = cumulativeMeters[segmentEnd - 1]
            let segmentMeters = cumulativeMeters[segmentEnd] - startMeters
            let fraction = segmentMeters > 0 ? min(max((target - startMeters) / segmentMeters, 0), 1) : 0
            let start = coordinates[segmentEnd - 1]
            let end = coordinates[segmentEnd]
            markers.append(
                RunRouteKilometerMarker(
                    kilometer: kilometer,
                    coordinate: CLLocationCoordinate2D(
                        latitude: start.latitude + (end.latitude - start.latitude) * fraction,
                        longitude: start.longitude + (end.longitude - start.longitude) * fraction
                    )
                )
            )
        }
        return markers
    }
}
