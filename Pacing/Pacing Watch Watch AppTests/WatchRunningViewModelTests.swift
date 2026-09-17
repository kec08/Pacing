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
}
