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
}
