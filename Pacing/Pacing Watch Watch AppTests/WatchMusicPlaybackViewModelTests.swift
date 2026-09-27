import Combine
import XCTest
@testable import Pacing_Watch_Watch_App

@MainActor
final class WatchMusicPlaybackViewModelTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    func testTogglePlaybackUpdatesWatchUIBeforePhoneConfirmation() async {
        let repository = MusicPlaybackRepositorySpy(snapshot: makeSnapshot(isPlaying: true))
        let viewModel = WatchMusicPlaybackViewModel(repository: repository)
        await settleSnapshotDelivery()

        viewModel.togglePlayback()

        XCTAssertFalse(viewModel.snapshot.isPlaying)
        XCTAssertEqual(repository.sentCommands, [.setPlaybackState])
        XCTAssertEqual(repository.sentPlaybackStates, [false])
    }

    func testTogglePlaybackKeepsOptimisticIconUntilMatchingPhoneSnapshotArrives() async {
        let repository = MusicPlaybackRepositorySpy(snapshot: makeSnapshot(isPlaying: true))
        let viewModel = WatchMusicPlaybackViewModel(repository: repository)
        await settleSnapshotDelivery()

        viewModel.togglePlayback()
        repository.publish(makeSnapshot(isPlaying: true))
        await settleSnapshotDelivery()

        XCTAssertFalse(viewModel.snapshot.isPlaying)

        repository.publish(makeSnapshot(isPlaying: false))
        await settleSnapshotDelivery()

        XCTAssertFalse(viewModel.snapshot.isPlaying)
    }

    func testPlayRequestIgnoresPausedSnapshotsUntilPlayingSnapshotArrives() async {
        let repository = MusicPlaybackRepositorySpy(snapshot: makeSnapshot(isPlaying: false))
        let viewModel = WatchMusicPlaybackViewModel(repository: repository)
        await settleSnapshotDelivery()

        viewModel.togglePlayback()
        repository.publish(makeSnapshot(isPlaying: false))
        await settleSnapshotDelivery()

        XCTAssertTrue(viewModel.snapshot.isPlaying)

        repository.publish(makeSnapshot(isPlaying: true))
        await settleSnapshotDelivery()

        XCTAssertTrue(viewModel.snapshot.isPlaying)
    }

    func testRapidTapsSendTheLatestPlaybackStateInsteadOfToggleCommands() async {
        let repository = MusicPlaybackRepositorySpy(snapshot: makeSnapshot(isPlaying: false))
        let viewModel = WatchMusicPlaybackViewModel(repository: repository)
        await settleSnapshotDelivery()

        viewModel.togglePlayback()
        viewModel.togglePlayback()

        XCTAssertEqual(repository.sentCommands, [.setPlaybackState, .setPlaybackState])
        XCTAssertEqual(repository.sentPlaybackStates, [true, false])
        XCTAssertFalse(viewModel.snapshot.isPlaying)
    }

    func testSelectingTrackUpdatesTitleAndArtworkImmediately() async {
        let firstTrack = makeTrack(id: "first", title: "첫 번째 곡")
        let secondTrack = makeTrack(id: "second", title: "두 번째 곡")
        let repository = MusicPlaybackRepositorySpy(
            snapshot: makeSnapshot(isPlaying: true, tracks: [firstTrack, secondTrack])
        )
        let viewModel = WatchMusicPlaybackViewModel(repository: repository)
        await settleSnapshotDelivery()

        viewModel.play(secondTrack)

        XCTAssertEqual(viewModel.snapshot.title, "두 번째 곡")
        XCTAssertEqual(viewModel.snapshot.artworkURL, secondTrack.artworkURL)
        XCTAssertEqual(repository.sentCommands, [.play])
        XCTAssertEqual(repository.sentSongIDs, ["second"])
    }

    func testSelectingTrackKeepsOptimisticTrackUntilMatchingPhoneSnapshotArrives() async {
        let firstTrack = makeTrack(id: "first", title: "첫 번째 곡")
        let secondTrack = makeTrack(id: "second", title: "두 번째 곡")
        let repository = MusicPlaybackRepositorySpy(
            snapshot: makeSnapshot(isPlaying: true, tracks: [firstTrack, secondTrack])
        )
        let viewModel = WatchMusicPlaybackViewModel(repository: repository)
        await settleSnapshotDelivery()

        viewModel.play(secondTrack)
        repository.publish(makeSnapshot(isPlaying: true, tracks: [firstTrack, secondTrack]))
        await settleSnapshotDelivery()

        XCTAssertEqual(viewModel.snapshot.title, "두 번째 곡")
    }

    private func makeSnapshot(
        isPlaying: Bool,
        tracks: [WatchMusicTrack]? = nil
    ) -> WatchMusicPlaybackSnapshot {
        let tracks = tracks ?? [makeTrack(id: "first", title: "첫 번째 곡")]
        return WatchMusicPlaybackSnapshot(
            updatedAt: Date().timeIntervalSince1970,
            title: tracks[0].title,
            artist: tracks[0].artist,
            artworkURL: tracks[0].artworkURL,
            artworkData: nil,
            isPlaying: isPlaying,
            recentlyPlayed: tracks,
            playlistTracks: tracks
        )
    }

    private func makeTrack(id: String, title: String) -> WatchMusicTrack {
        WatchMusicTrack(
            id: id,
            title: title,
            artist: "Pacing",
            artworkURL: "https://example.com/\(id).jpg",
            artworkData: nil
        )
    }

    private func settleSnapshotDelivery() async {
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}

@MainActor
private final class MusicPlaybackRepositorySpy: WatchMusicPlaybackRepository {
    private let subject: CurrentValueSubject<WatchMusicPlaybackSnapshot, Never>
    private(set) var sentCommands: [WatchMusicPlaybackCommand] = []
    private(set) var sentSongIDs: [String?] = []

    var snapshot: AnyPublisher<WatchMusicPlaybackSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    init(snapshot: WatchMusicPlaybackSnapshot) {
        subject = CurrentValueSubject(snapshot)
    }

    func refresh() {}

    private(set) var sentPlaybackStates: [Bool?] = []

    func send(_ command: WatchMusicPlaybackCommand, songID: String?, isPlaying: Bool?) {
        sentCommands.append(command)
        sentSongIDs.append(songID)
        sentPlaybackStates.append(isPlaying)
    }

    func publish(_ snapshot: WatchMusicPlaybackSnapshot) {
        subject.send(snapshot)
    }
}
