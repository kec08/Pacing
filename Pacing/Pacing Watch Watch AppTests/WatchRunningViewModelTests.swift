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

    func testEndedPhoneSnapshotDoesNotOpenRunExperienceFromIdle() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)
        let endedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = PhoneRunSnapshot(
            state: .ended,
            elapsedSeconds: 120,
            distanceKilometers: 1,
            paceMinutesPerKilometer: 5,
            sentAt: endedAt
        )

        viewModel.applyPhoneSnapshot(snapshot)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testEndedPhoneSnapshotReturnsAnActiveRunToIdle() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)
        let startedAt = Date(timeIntervalSince1970: 900)
        viewModel.applyPhoneSnapshot(
            PhoneRunSnapshot(
                state: .running,
                elapsedSeconds: 60,
                distanceKilometers: 0.5,
                paceMinutesPerKilometer: 5,
                sentAt: startedAt
            )
        )

        viewModel.applyPhoneSnapshot(
            PhoneRunSnapshot(
                state: .ended,
                elapsedSeconds: 120,
                distanceKilometers: 1,
                paceMinutesPerKilometer: 5,
                sentAt: Date(timeIntervalSince1970: 1_000)
            )
        )

        XCTAssertEqual(viewModel.state, .idle)
    }
}
