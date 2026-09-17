import XCTest
@testable import Pacing_Watch_Watch_App

@MainActor
final class WatchRunningViewModelTests: XCTestCase {
    func testPreviewModeStartsWithoutHealthKitSession() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)

        viewModel.start()

        XCTAssertEqual(viewModel.state, .running)
    }

    func testPreviewModeEndsWithoutHealthKitSession() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)
        viewModel.start()

        viewModel.end()

        XCTAssertEqual(viewModel.state, .ended)
    }
}
