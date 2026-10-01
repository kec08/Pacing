//
//  Pacing_Watch_Watch_AppTests.swift
//  Pacing Watch Watch AppTests
//
//  Created by 김은찬 on 9/17/26.
//

import XCTest
@testable import Pacing_Watch_Watch_App

final class Pacing_Watch_Watch_AppTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testListenTogetherSnapshotPreservesArtworkAndParticipantRoles() throws {
        let artwork = Data([0x01, 0x02, 0x03])
        let snapshot = WatchListenTogetherSnapshot(
            updatedAt: 123,
            isActive: true,
            sessionID: "session",
            title: "Hyperventilation",
            artist: "RADWIMPS",
            artworkURL: "https://example.com/artwork.jpg",
            artworkData: artwork,
            startedAt: Date(timeIntervalSince1970: 100),
            participants: [
                WatchListenTogetherParticipant(id: "host", nickname: "은찬", role: "호스트", profileImageData: artwork),
                WatchListenTogetherParticipant(id: "guest", nickname: "윤재", role: "게스트", profileImageData: nil)
            ]
        )

        let decoded = try JSONDecoder().decode(
            WatchListenTogetherSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.participants.map(\.role), ["호스트", "게스트"])
        XCTAssertEqual(decoded.artworkData, artwork)
    }

    func testInactiveListenTogetherSnapshotContainsNoStaleParticipants() {
        XCTAssertFalse(WatchListenTogetherSnapshot.inactive.isActive)
        XCTAssertTrue(WatchListenTogetherSnapshot.inactive.participants.isEmpty)
        XCTAssertNil(WatchListenTogetherSnapshot.inactive.artworkData)
    }

}
