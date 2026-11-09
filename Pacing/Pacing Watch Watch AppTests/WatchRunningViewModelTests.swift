import XCTest
@testable import Pacing_Watch_Watch_App

@MainActor
final class WatchRunningViewModelTests: XCTestCase {
    func testPhoneSnapshotUsesPhoneAveragePaceAndDistance() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)
        let snapshot = PhoneRunSnapshot(
            state: .running,
            elapsedSeconds: 222,
            distanceKilometers: 0.5,
            paceMinutesPerKilometer: 3 + 1.0 / 60,
            averagePaceMinutesPerKilometer: 5.4,
            currentPaceText: "3'00\"",
            averagePaceText: "5'24\"",
            lapPaces: [PhoneRunLapPace(kilometer: 1, paceText: "5'24\"")],
            sentAt: .now
        )

        viewModel.applyPhoneSnapshot(snapshot)

        XCTAssertEqual(viewModel.metrics.formattedDistance, "0.50")
        XCTAssertEqual(viewModel.metrics.formattedAveragePace, "5'24\"")
        XCTAssertEqual(viewModel.metrics.formattedValue(for: .currentPace), "3'00\"")
        XCTAssertEqual(viewModel.secondaryMetrics, [.distance, .currentPace])
        XCTAssertEqual(viewModel.metrics.splits.first?.paceText, "5'24\"")
    }

    func testPhoneSnapshotWithoutValidAveragePaceShowsPlaceholder() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)
        viewModel.applyPhoneSnapshot(PhoneRunSnapshot(
            state: .running,
            elapsedSeconds: 222,
            distanceKilometers: 0.06,
            paceMinutesPerKilometer: 0,
            averagePaceMinutesPerKilometer: nil,
            currentPaceText: "--'--\"",
            averagePaceText: "--'--\"",
            lapPaces: nil,
            sentAt: .now
        ))

        XCTAssertEqual(viewModel.metrics.formattedAveragePace, "--'--\"")
    }

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
            averagePaceMinutesPerKilometer: nil,
            currentPaceText: nil,
            averagePaceText: nil,
            lapPaces: nil,
            sentAt: endedAt
        )

        viewModel.applyPhoneSnapshot(snapshot)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testEndedPhoneSnapshotShowsSummaryForAnActiveRun() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)
        let startedAt = Date(timeIntervalSince1970: 900)
        viewModel.applyPhoneSnapshot(
            PhoneRunSnapshot(
                state: .running,
                elapsedSeconds: 60,
                distanceKilometers: 0.5,
                paceMinutesPerKilometer: 5,
                averagePaceMinutesPerKilometer: nil,
                currentPaceText: nil,
                averagePaceText: nil,
                lapPaces: nil,
                sentAt: startedAt
            )
        )

        viewModel.applyPhoneSnapshot(
            PhoneRunSnapshot(
                state: .ended,
                elapsedSeconds: 120,
                distanceKilometers: 1,
                paceMinutesPerKilometer: 5,
                averagePaceMinutesPerKilometer: nil,
                currentPaceText: nil,
                averagePaceText: nil,
                lapPaces: nil,
                sentAt: Date(timeIntervalSince1970: 1_000)
            )
        )

        XCTAssertEqual(viewModel.state, .ended)
        XCTAssertEqual(viewModel.metrics.formattedDistance, "1.00")
        XCTAssertEqual(viewModel.metrics.formattedElapsed, "02:00")
    }

    func testLatePhoneEndSnapshotUpdatesCompletedSummary() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)
        viewModel.applyPhoneSnapshot(PhoneRunSnapshot(
            state: .running,
            elapsedSeconds: 60,
            distanceKilometers: 0.5,
            paceMinutesPerKilometer: 5,
            averagePaceMinutesPerKilometer: 5,
            currentPaceText: "5'00\"",
            averagePaceText: "5'00\"",
            lapPaces: nil,
            sentAt: .now
        ))
        viewModel.end(sendCommand: false)

        viewModel.applyPhoneSnapshot(PhoneRunSnapshot(
            state: .ended,
            elapsedSeconds: 120,
            distanceKilometers: 1,
            paceMinutesPerKilometer: 5,
            averagePaceMinutesPerKilometer: 5,
            currentPaceText: "5'00\"",
            averagePaceText: "5'00\"",
            lapPaces: [PhoneRunLapPace(kilometer: 1, paceText: "5'00\"")],
            sentAt: .now
        ))

        XCTAssertEqual(viewModel.metrics.formattedDistance, "1.00")
        XCTAssertEqual(viewModel.metrics.formattedElapsed, "02:00")
        XCTAssertEqual(viewModel.metrics.splits.first?.paceText, "5'00\"")
    }

    func testPhoneFinishCommandShowsSummaryForAnActiveRun() {
        let viewModel = WatchRunningViewModel(usesPreviewMetrics: true)
        viewModel.applyPhoneSnapshot(
            PhoneRunSnapshot(
                state: .running,
                elapsedSeconds: 60,
                distanceKilometers: 0.5,
                paceMinutesPerKilometer: 5,
                averagePaceMinutesPerKilometer: nil,
                currentPaceText: nil,
                averagePaceText: nil,
                lapPaces: nil,
                sentAt: Date(timeIntervalSince1970: 900)
            )
        )

        viewModel.applyPhoneCommand(
            PhoneRunCommand(
                action: .finish,
                sender: .phone,
                sessionID: UUID()
            )
        )

        XCTAssertEqual(viewModel.state, .ended)
    }
}
