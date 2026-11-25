import XCTest
import CoreLocation
@testable import Pacing

final class RunActivityDetailRedesignTests: XCTestCase {
    /// 위도 0도에서 경도 1도는 약 111.32km라 경도 0.01도는 약 1.113km다.
    private func straightRoute(kilometers: Double) -> [CLLocationCoordinate2D] {
        let metersPerDegree = 111_319.49
        let endLongitude = kilometers * 1_000 / metersPerDegree
        return [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: endLongitude / 2),
            CLLocationCoordinate2D(latitude: 0, longitude: endLongitude)
        ]
    }

    func testKilometerMarkersPlaceEachKilometerAlongRoute() {
        let route = straightRoute(kilometers: 3.5)
        let markers = RunRouteKilometerMarkers.markers(for: route, recordedDistanceKilometers: 3.5)

        XCTAssertEqual(markers.map(\.kilometer), [1, 2, 3])
        let origin = CLLocation(latitude: 0, longitude: 0)
        for marker in markers {
            let meters = origin.distance(
                from: CLLocation(latitude: marker.coordinate.latitude, longitude: marker.coordinate.longitude)
            )
            XCTAssertEqual(meters, Double(marker.kilometer) * 1_000, accuracy: 5)
        }
    }

    func testKilometerMarkersScaleRouteLengthToRecordedDistance() {
        // GPS 경로는 2km인데 Watch 기록 거리는 4km면 경로 위 0.5km마다 1km 라벨이 놓인다.
        let route = straightRoute(kilometers: 2)
        let markers = RunRouteKilometerMarkers.markers(for: route, recordedDistanceKilometers: 4.2)

        XCTAssertEqual(markers.map(\.kilometer), [1, 2, 3, 4])
        let first = CLLocation(latitude: 0, longitude: 0).distance(
            from: CLLocation(latitude: markers[0].coordinate.latitude, longitude: markers[0].coordinate.longitude)
        )
        XCTAssertEqual(first, 2_000 / 4.2, accuracy: 5)
    }

    func testKilometerMarkersSkipLabelOverlappingFinishAndThinLongRuns() {
        XCTAssertEqual(
            RunRouteKilometerMarkers.markers(for: straightRoute(kilometers: 3.02), recordedDistanceKilometers: 3.02)
                .map(\.kilometer),
            [1, 2]
        )
        XCTAssertEqual(
            RunRouteKilometerMarkers.markers(for: straightRoute(kilometers: 16.5), recordedDistanceKilometers: 16.5)
                .map(\.kilometer),
            [3, 6, 9, 12, 15]
        )
        XCTAssertEqual(
            [5.2, 7.9, 8, 10.05, 14.9, 15, 20, 24.9, 25, 42.2].map(RunRouteKilometerMarkers.interval(forDistanceKilometers:)),
            [1, 1, 2, 2, 2, 3, 3, 3, 5, 5]
        )
        XCTAssertEqual(
            RunRouteKilometerMarkers.markers(for: straightRoute(kilometers: 10.3), recordedDistanceKilometers: 10.3)
                .map(\.kilometer),
            [2, 4, 6, 8, 10]
        )
        XCTAssertTrue(
            RunRouteKilometerMarkers.markers(for: straightRoute(kilometers: 0.9), recordedDistanceKilometers: 0.9)
                .isEmpty
        )
    }

    func testSplitBarIsLongestForFastestLap() {
        XCTAssertEqual(RunSplitBarScale.widthFraction(pace: 4.97, fastest: 4.97, slowest: 5.57), 1, accuracy: 0.0001)
        XCTAssertEqual(
            RunSplitBarScale.widthFraction(pace: 5.57, fastest: 4.97, slowest: 5.57),
            RunSplitBarScale.minimumFraction,
            accuracy: 0.0001
        )
        let middle = RunSplitBarScale.widthFraction(pace: 5.27, fastest: 4.97, slowest: 5.57)
        XCTAssertGreaterThan(middle, RunSplitBarScale.minimumFraction)
        XCTAssertLessThan(middle, 1)
        XCTAssertEqual(RunSplitBarScale.widthFraction(pace: 5.0, fastest: 5.0, slowest: 5.0), 1)
        XCTAssertEqual(RunSplitBarScale.widthFraction(pace: .nan, fastest: 5.0, slowest: 6.0), RunSplitBarScale.minimumFraction)
    }

    func testLapHeartRateResolverQueriesEachLapWindow() async {
        let start = Date(timeIntervalSince1970: 1_000)
        let laps = [
            RunLapPace(kilometer: 1, pace: 5.0),
            RunLapPace(kilometer: 2, pace: 5.2),
            RunLapPace(kilometer: 3, pace: 5.1)
        ]
        let windows: [Int: DateInterval] = [
            1: DateInterval(start: start, duration: 300),
            2: DateInterval(start: start.addingTimeInterval(300), duration: 312)
        ]
        let repository = HeartRateRepositoryStub(values: [
            start: 150,
            start.addingTimeInterval(300): 158
        ])

        let resolved = await RunLapHeartRateResolver.resolve(laps: laps, windows: windows, repository: repository)

        XCTAssertEqual(resolved.map(\.averageHeartRate), [150, 158, nil])
        XCTAssertEqual(resolved.map(\.pace), [5.0, 5.2, 5.1])
    }
}

private final class HeartRateRepositoryStub: HeartRateRepository {
    let values: [Date: Double]

    init(values: [Date: Double]) {
        self.values = values
    }

    func requestReadAuthorization() async -> Bool { true }

    func averageHeartRate(from startDate: Date, to endDate: Date) async -> Double? {
        values[startDate]
    }
}
