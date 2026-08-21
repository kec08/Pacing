//
//  PacingTests.swift
//  PacingTests
//
//  Created by 김은찬 on 6/25/26.
//

import XCTest
@testable import Pacing
import CoreLocation
import MapKit

final class PacingTests: XCTestCase {
    func testWeeklyDateRangeStartsOnMondayAndExcludesPreviousSunday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone

        let thursday = formatter.date(from: "2026-07-30T12:00:00+09:00")!
        let sunday = formatter.date(from: "2026-07-26T12:00:00+09:00")!
        let monday = formatter.date(from: "2026-07-27T00:00:00+09:00")!

        let interval = WeeklyDateRange.interval(containing: thursday, calendar: calendar)

        XCTAssertFalse(interval.contains(sunday))
        XCTAssertTrue(interval.contains(monday))
    }

    func testLocationModeSupportsPlistArrayAndString() throws {
        XCTAssertTrue(LocationBackgroundConfiguration.supportsLocationMode(["location", "audio"]))
        XCTAssertTrue(LocationBackgroundConfiguration.supportsLocationMode("location audio"))
        XCTAssertTrue(LocationBackgroundConfiguration.supportsLocationMode("audio, location"))
        XCTAssertFalse(LocationBackgroundConfiguration.supportsLocationMode(["audio"]))
        XCTAssertFalse(LocationBackgroundConfiguration.supportsLocationMode(nil))
    }

    func testBackgroundUpdatesRequireAlwaysPermissionAndActiveRecording() throws {
        XCTAssertTrue(
            LocationBackgroundConfiguration.shouldEnableBackgroundUpdates(
                supportsLocationMode: true,
                authorizationStatus: .authorizedAlways,
                isRecordingRoute: true
            )
        )
        XCTAssertFalse(
            LocationBackgroundConfiguration.shouldEnableBackgroundUpdates(
                supportsLocationMode: true,
                authorizationStatus: .authorizedWhenInUse,
                isRecordingRoute: true
            )
        )
        XCTAssertFalse(
            LocationBackgroundConfiguration.shouldEnableBackgroundUpdates(
                supportsLocationMode: true,
                authorizationStatus: .authorizedAlways,
                isRecordingRoute: false
            )
        )
    }

    func testActiveRunnerFreshnessExpiresAfterTwoMinutes() {
        let referenceDate = Date(timeIntervalSince1970: 1_000)
        let freshRunner = ActiveRunner(
            id: "fresh", nickname: "러너", coordinate: CLLocationCoordinate2D(latitude: 37, longitude: 127),
            songTitle: "", artist: "", profileImageBase64: nil, updatedAt: 881_000
        )
        let staleRunner = ActiveRunner(
            id: "stale", nickname: "러너", coordinate: CLLocationCoordinate2D(latitude: 37, longitude: 127),
            songTitle: "", artist: "", profileImageBase64: nil, updatedAt: 879_000
        )

        XCTAssertTrue(freshRunner.isFresh(referenceDate: referenceDate))
        XCTAssertFalse(staleRunner.isFresh(referenceDate: referenceDate))
    }

    func testPaceRemainsHiddenUntilMeaningfulDistanceIsRecorded() {
        XCTAssertFalse(RunningPacePolicy.canDisplayPace(distanceKilometers: 0, elapsedSeconds: 30))
        XCTAssertFalse(RunningPacePolicy.canDisplayPace(distanceKilometers: 0.019, elapsedSeconds: 30))
        XCTAssertTrue(RunningPacePolicy.canDisplayPace(distanceKilometers: 0.02, elapsedSeconds: 30))
    }

    func testPacePolicyRejectsStationaryGPSDriftAndAcceptsRunningSegment() {
        XCTAssertFalse(
            RunningPacePolicy.isValidRunningSegment(
                distanceMeters: 4,
                timeInterval: 10,
                previousHorizontalAccuracy: 5,
                currentHorizontalAccuracy: 5
            )
        )
        XCTAssertTrue(
            RunningPacePolicy.isValidRunningSegment(
                distanceMeters: 6,
                timeInterval: 3,
                previousHorizontalAccuracy: 5,
                currentHorizontalAccuracy: 5
            )
        )
    }

    func testRunRecordHidesPaceForShortDistanceAndExcludesExtremePace() {
        let shortDistance = RunRecord(
            id: "short", startedAt: .now, duration: 314, distance: 0.01, avgPace: 523.3,
            routeCoordinates: [], lapPaces: []
        )
        let extremePace = RunRecord(
            id: "extreme", startedAt: .now, duration: 300, distance: 0.20, avgPace: 30.01,
            routeCoordinates: [], lapPaces: []
        )

        XCTAssertFalse(shortDistance.isPaceValid)
        XCTAssertFalse(extremePace.isPaceValid)
        XCTAssertEqual(shortDistance.displayPace, 0)
        XCTAssertEqual(RunRecord.formattedPace(shortDistance.displayPace), "--'--\"")
    }

    func testRunRecordAcceptsPaceAtValidationBoundaries() {
        let validRecord = RunRecord(
            id: "valid", startedAt: .now, duration: 180, distance: 0.10, avgPace: 30.0,
            routeCoordinates: [], lapPaces: []
        )

        XCTAssertTrue(validRecord.isPaceValid)
        XCTAssertEqual(RunRecord.formattedPace(validRecord.displayPace), "30'00\"")
    }

    func testEmailValidatorRejectsInvalidEmail() {
        XCTAssertEqual(
            AuthInputValidator.emailError(for: "pacing.example.com"),
            "올바른 이메일 주소를 입력해주세요."
        )
    }

    func testSignUpValidatorRequiresMatchingSecurePassword() {
        XCTAssertEqual(
            AuthInputValidator.signUpError(
                email: "reviewer@pacing.app",
                password: "pacing123",
                confirmation: "different123"
            ),
            "비밀번호가 일치하지 않아요."
        )
    }

    func testSignUpValidatorAcceptsValidCredentials() {
        XCTAssertNil(
            AuthInputValidator.signUpError(
                email: "reviewer@pacing.app",
                password: "pacing123",
                confirmation: "pacing123"
            )
        )
    }

    func testAppleNonceStoreUsesNonceClaimToResolveMatchingRawNonce() {
        var nonceStore = AppleNonceStore()
        let rawNonce = "raw-nonce-for-apple"
        let nonceHash = nonceStore.register(rawNonce: rawNonce)
        let idToken = "header.eyJub25jZSI6XCIi.signature"

        let payload = "{\"nonce\":\"\(nonceHash)\"}"
            .data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let tokenWithNonce = "header.\(payload).signature"

        XCTAssertEqual(AppleNonceStore.nonceHash(fromIDToken: tokenWithNonce), nonceHash)
        XCTAssertEqual(nonceStore.consume(rawNonceHash: nonceHash), rawNonce)
        XCTAssertNil(AppleNonceStore.nonceHash(fromIDToken: idToken))
    }

    func testRunRouteGradientPreservesSegmentCoverage() {
        let coordinates = (0..<101).map {
            CLLocationCoordinate2D(latitude: 37 + Double($0) * 0.001, longitude: 127)
        }

        let segments = RunRouteGradient.segments(from: coordinates, maximumSegmentCount: 10)

        XCTAssertEqual(segments.count, 10)
        XCTAssertEqual(segments.first?.coordinates.first?.latitude, coordinates.first?.latitude)
        XCTAssertEqual(segments.last?.coordinates.last?.latitude, coordinates.last?.latitude)
    }

    func testRunStatisticsSummaryUsesSinglePassResult() {
        let validRecord = RunRecord(
            id: "valid", startedAt: .now, duration: 600, distance: 2, avgPace: 5,
            routeCoordinates: [], lapPaces: []
        )
        let invalidRecord = RunRecord(
            id: "invalid", startedAt: .now, duration: 300, distance: 0.01, avgPace: 50,
            routeCoordinates: [], lapPaces: []
        )

        let summary = RunStatisticsCalculator.summary(from: [validRecord, invalidRecord])

        XCTAssertEqual(summary.totalDistance, 2.01, accuracy: 0.0001)
        XCTAssertEqual(summary.totalDuration, 900)
        XCTAssertEqual(summary.averagePace, 5, accuracy: 0.0001)
    }

    func testRunRouteBoundsCalculatesExpectedRegion() {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 37.0, longitude: 127.0),
            CLLocationCoordinate2D(latitude: 37.1, longitude: 127.2)
        ]

        let region = RunRouteBounds.region(
            for: coordinates,
            paddingMultiplier: 1.5,
            minimumDelta: 0.003
        )

        guard let region else {
            return XCTFail("경로 좌표가 있으면 지도 영역을 계산해야 합니다.")
        }
        XCTAssertEqual(region.center.latitude, 37.05, accuracy: 0.0001)
        XCTAssertEqual(region.center.longitude, 127.1, accuracy: 0.0001)
        XCTAssertEqual(region.span.latitudeDelta, 0.15, accuracy: 0.0001)
        XCTAssertEqual(region.span.longitudeDelta, 0.3, accuracy: 0.0001)
    }

}
