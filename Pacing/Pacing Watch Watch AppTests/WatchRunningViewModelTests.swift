import XCTest
@testable import Pacing_Watch_Watch_App

@MainActor
final class WatchRunningViewModelTests: XCTestCase {
    func testPreviewModeStartsCountdownWithoutHealthKitSession() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)

        viewModel.start()

        XCTAssertEqual(viewModel.state, .countdown(3))
    }

    func testResetCancelsPreviewCountdown() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)
        viewModel.start()

        viewModel.reset()

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testSelectingMetricUpdatesLargeDashboardMetric() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)

        viewModel.selectDisplayMetric(.heartRate)

        XCTAssertEqual(viewModel.displayMetric, .heartRate)
    }

    func testSelectingSecondaryMetricPublishesChangedSlot() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)

        viewModel.selectNextSecondaryMetric(at: 0)

        XCTAssertNotEqual(viewModel.secondaryMetrics[0], .distance)
    }
}
