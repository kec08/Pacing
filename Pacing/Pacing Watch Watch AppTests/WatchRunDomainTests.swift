import XCTest
@testable import Pacing_Watch_Watch_App

final class WatchRunDomainTests: XCTestCase {
    func testActiveStateContainsRunningPausedAndEndingOnly() {
        XCTAssertTrue(WatchRunState.running.isActive)
        XCTAssertTrue(WatchRunState.paused.isActive)
        XCTAssertTrue(WatchRunState.ending.isActive)
        XCTAssertFalse(WatchRunState.idle.isActive)
        XCTAssertFalse(WatchRunState.ended.isActive)
    }

    func testDisplayMetricCyclesInDashboardOrder() {
        XCTAssertEqual(WatchRunDisplayMetric.elapsed.next(), .distance)
        XCTAssertEqual(WatchRunDisplayMetric.distance.next(), .averagePace)
        XCTAssertEqual(WatchRunDisplayMetric.averagePace.next(), .heartRate)
        XCTAssertEqual(WatchRunDisplayMetric.heartRate.next(), .calories)
        XCTAssertEqual(WatchRunDisplayMetric.calories.next(), .elevationGain)
        XCTAssertEqual(WatchRunDisplayMetric.elevationGain.next(), .elapsed)
    }

    func testMetricsFormatsElapsedDistanceAndPace() {
        let metrics = WatchRunMetrics(
            elapsed: 3_661,
            distanceMeters: 1_234,
            currentPaceSecondsPerKilometer: 321,
            heartRateBeatsPerMinute: nil,
            activeEnergyKilocalories: nil
        )

        XCTAssertEqual(metrics.formattedElapsed, "1:01:01")
        XCTAssertEqual(metrics.formattedDistance, "1.23")
        XCTAssertEqual(metrics.formattedPace, "5'21\"")
    }

    func testRunHistorySnapshotKeepsMonthlySummaryAndRecentRunDetails() throws {
        let run = PhoneRunHistoryItem(
            id: "run-1",
            startedAt: Date(timeIntervalSince1970: 1_000),
            durationSeconds: 1_800,
            distanceKilometers: 5.2,
            averagePaceMinutesPerKilometer: 5.77,
            elevationGainMeters: 42,
            averageHeartRate: 155,
            averageCadence: 168,
            calories: 322,
            routePoints: [PhoneRunHistoryRoutePoint(latitude: 37.5, longitude: 127.0)]
        )
        let snapshot = PhoneRunHistorySnapshot(
            monthDistanceKilometers: 12.7,
            monthRunCount: 3,
            recentRuns: [run],
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        let decoded = try JSONDecoder().decode(
            PhoneRunHistorySnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.recentRuns.first?.distanceKilometers, 5.2)
        XCTAssertEqual(decoded.recentRuns.first?.calories, 322)
    }

    func testSessionUnavailableDoesNotExposePreparationFailureMessage() {
        XCTAssertEqual(WatchRunError.sessionUnavailable.userMessage, "")
    }
}
