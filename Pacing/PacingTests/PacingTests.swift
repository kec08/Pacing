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

}
