//
//  PacingTests.swift
//  PacingTests
//
//  Created by 김은찬 on 6/25/26.
//

import XCTest
@testable import Pacing
import CoreLocation

final class PacingTests: XCTestCase {
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
}
