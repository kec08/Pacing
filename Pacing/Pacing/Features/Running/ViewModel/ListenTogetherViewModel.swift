import SwiftUI
import Combine
import MediaPlayer
import MusicKit
import FirebaseAuth

@MainActor
final class ListenTogetherViewModel: ObservableObject {
    @Published var incomingRequest: ListenSession? = nil   // 수신된 요청
    @Published var activeSession: ListenSession? = nil     // 활성 세션
    @Published var isHost: Bool = false
    @Published var sessionStartDate: Date? = nil

    private var myUID: String { Auth.auth().currentUser?.uid ?? "" }
    private var myNickname: String { UserDefaults.standard.string(forKey: "nickname") ?? "러너" }

    // MARK: - 요청 수신 감지 시작
    func startObservingRequests() {
        RealtimeDBService.shared.observeIncomingRequests(uid: myUID) { [weak self] session in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let session = session, session.status == "pending" {
                    self.incomingRequest = session
                }
            }
        }
    }

    func stopObservingRequests() {
        RealtimeDBService.shared.stopObservingIncomingRequests(uid: myUID)
    }

    // MARK: - 같이 듣기 요청 보내기 (호스트)
    func sendRequest(to runner: NearbyRunner, musicVM: RunningMusicViewModel) {
        let player = MPMusicPlayerController.systemMusicPlayer
        let song = currentSongSnapshot(from: musicVM, player: player)
        let position = player.currentPlaybackTime

        let sessionID = RealtimeDBService.shared.createListenSession(
            hostUID: myUID, hostNickname: myNickname,
            guestUID: runner.id, guestNickname: runner.nickname,
            songStoreID: song.storeID, songTitle: song.title, artistName: song.artist,
            position: position
        )

        activeSession = ListenSession(
            id: sessionID, hostUID: myUID, hostNickname: myNickname,
            guestUID: runner.id, guestNickname: runner.nickname,
            songStoreID: song.storeID, songTitle: song.title, artistName: song.artist,
            playbackPosition: position,
            serverTimestamp: Date().timeIntervalSince1970,
            status: "pending", isPlaying: player.playbackState == .playing
        )
        isHost = true
        sessionStartDate = Date()

        observeSession(sessionID: sessionID, musicVM: musicVM)
    }

    // MARK: - 요청 수락 (게스트)
    func acceptRequest(musicVM: RunningMusicViewModel) async {
        guard let session = incomingRequest else { return }
        RealtimeDBService.shared.acceptSession(sessionID: session.id, guestUID: myUID)
        activeSession = session
        isHost = false
        incomingRequest = nil
        sessionStartDate = Date()

        observeSession(sessionID: session.id, musicVM: musicVM)
        await syncMusic(session: session)
    }

    // MARK: - 요청 거절
    func declineRequest() {
        guard let session = incomingRequest else { return }
        RealtimeDBService.shared.rejectSession(sessionID: session.id, guestUID: myUID)
        incomingRequest = nil
    }

    // MARK: - 세션 종료
    func endSession() {
        guard let session = activeSession else { return }
        RealtimeDBService.shared.endSession(sessionID: session.id)
        cleanup()
    }

    // MARK: - 호스트: 재생 상태 브로드캐스트
    func broadcastIfHost(musicVM: RunningMusicViewModel) {
        guard isHost, let session = activeSession, session.status == "active" else { return }
        let player = MPMusicPlayerController.systemMusicPlayer
        let song = currentSongSnapshot(from: musicVM, player: player)
        RealtimeDBService.shared.updateSessionPlayback(
            sessionID: session.id,
            songStoreID: song.storeID,
            songTitle: song.title,
            artistName: song.artist,
            position: player.currentPlaybackTime,
            isPlaying: player.playbackState == .playing
        )
    }

    // MARK: - 세션 구독
    private func observeSession(sessionID: String, musicVM: RunningMusicViewModel) {
        RealtimeDBService.shared.observeSession(sessionID: sessionID) { [weak self] session in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch session.status {
                case "rejected", "ended":
                    self.cleanup()
                case "active":
                    if !self.isHost {
                        // 곡이 바뀌었거나 아직 같은 곡을 재생 중이 아니면 동기화
                        if self.shouldSyncMusic(with: session) {
                            await self.syncMusic(session: session)
                        }
                        // 재생/일시정지 동기화
                        let player = MPMusicPlayerController.systemMusicPlayer
                        if session.isPlaying && player.playbackState != .playing {
                            player.play()
                        } else if !session.isPlaying && player.playbackState == .playing {
                            player.pause()
                        }
                    }
                    self.activeSession = session
                default:
                    self.activeSession = session
                }
            }
        }
    }

    // MARK: - MusicKit 싱크 (게스트)
    private func syncMusic(session: ListenSession) async {
        guard !session.songStoreID.isEmpty || !session.songTitle.isEmpty else { return }
        let player = MPMusicPlayerController.systemMusicPlayer

        let latency = Date().timeIntervalSince1970 - (session.serverTimestamp / 1000.0)
        let targetPosition = max(0, session.playbackPosition + latency)

        if await syncByStoreID(session: session, targetPosition: targetPosition, player: player) {
            return
        }

        await syncByLibrarySearch(session: session, targetPosition: targetPosition, player: player)
    }

    private func syncByStoreID(
        session: ListenSession,
        targetPosition: TimeInterval,
        player: MPMusicPlayerController
    ) async -> Bool {
        guard !session.songStoreID.isEmpty else { return false }
        player.setQueue(with: [session.songStoreID])
        do {
            try await player.prepareToPlay()
            player.currentPlaybackTime = targetPosition
            if session.isPlaying {
                player.play()
            } else {
                player.pause()
            }
            return true
        } catch {
            print("[ListenTogether] storeID sync failed: \(session.songStoreID), error: \(error.localizedDescription)")
            return false
        }
    }

    private func syncByLibrarySearch(
        session: ListenSession,
        targetPosition: TimeInterval,
        player: MPMusicPlayerController
    ) async {
        guard !session.songTitle.isEmpty else { return }
        let titlePredicate = MPMediaPropertyPredicate(
            value: session.songTitle,
            forProperty: MPMediaItemPropertyTitle,
            comparisonType: .equalTo
        )
        let query = MPMediaQuery()
        query.addFilterPredicate(titlePredicate)

        if let item = query.items?.first {
            let collection = MPMediaItemCollection(items: [item])
            player.setQueue(with: collection)
            try? await player.prepareToPlay()
            player.currentPlaybackTime = targetPosition
            if session.isPlaying {
                player.play()
            } else {
                player.pause()
            }
        } else {
            print("[ListenTogether] library fallback failed: \(session.songTitle) - \(session.artistName)")
        }
    }

    private func shouldSyncMusic(with session: ListenSession) -> Bool {
        let player = MPMusicPlayerController.systemMusicPlayer
        let currentStoreID = player.nowPlayingItem?.playbackStoreID ?? ""
        if !session.songStoreID.isEmpty, currentStoreID != session.songStoreID {
            return true
        }
        return activeSession?.songStoreID != session.songStoreID
    }

    private func currentSongSnapshot(
        from musicVM: RunningMusicViewModel,
        player: MPMusicPlayerController
    ) -> (storeID: String, title: String, artist: String) {
        let musicSnapshot = musicVM.currentSongSnapshot()
        let mediaItem = player.nowPlayingItem
        let storeID = mediaItem?.playbackStoreID.nonEmpty
            ?? musicSnapshot?.songStoreID.nonEmpty
            ?? ""
        let title = musicSnapshot?.title.nonEmpty
            ?? mediaItem?.title?.nonEmpty
            ?? ""
        let artist = musicSnapshot?.artistName.nonEmpty
            ?? mediaItem?.artist?.nonEmpty
            ?? ""
        return (storeID, title, artist)
    }

    private func cleanup() {
        RealtimeDBService.shared.stopObservingSession()
        activeSession = nil
        incomingRequest = nil
        isHost = false
        sessionStartDate = nil
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
