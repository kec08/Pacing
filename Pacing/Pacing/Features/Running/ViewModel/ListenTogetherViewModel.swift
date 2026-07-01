import SwiftUI
import Combine
import MediaPlayer
import MusicKit
import FirebaseAuth
import UIKit

@MainActor
final class ListenTogetherViewModel: ObservableObject {
    @Published var incomingRequest: ListenSession? = nil   // 수신된 요청
    @Published var activeSession: ListenSession? = nil     // 활성 세션
    @Published var isHost: Bool = false
    @Published var sessionStartDate: Date? = nil

    private var myUID: String { Auth.auth().currentUser?.uid ?? "" }
    private var myNickname: String { UserDefaults.standard.string(forKey: "nickname") ?? "러너" }
    private var lastIncomingRequestID: String?

    // MARK: - 요청 수신 감지 시작
    func startObservingRequests() {
        RealtimeDBService.shared.observeIncomingRequests(uid: myUID) { [weak self] session in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let session = session, session.status == "pending" {
                    if self.lastIncomingRequestID != session.id {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        self.lastIncomingRequestID = session.id
                    }
                    self.incomingRequest = session
                }
            }
        }
    }

    func stopObservingRequests() {
        RealtimeDBService.shared.stopObservingIncomingRequests(uid: myUID)
    }

    // MARK: - 같이 듣기 요청 보내기
    func sendRequest(to runner: NearbyRunner, musicVM: RunningMusicViewModel) {
        let sessionID = RealtimeDBService.shared.createListenSession(
            hostUID: myUID, hostNickname: myNickname,
            guestUID: runner.id, guestNickname: runner.nickname,
            songStoreID: "", songTitle: runner.songTitle, artistName: runner.artist,
            artworkURL: "",
            artworkData: "",
            position: 0
        )

        activeSession = ListenSession(
            id: sessionID, hostUID: myUID, hostNickname: myNickname,
            guestUID: runner.id, guestNickname: runner.nickname,
            songStoreID: "", songTitle: runner.songTitle, artistName: runner.artist,
            artworkURL: "",
            artworkData: "",
            playbackPosition: 0,
            serverTimestamp: Date().timeIntervalSince1970,
            status: "pending", isPlaying: true
        )
        isHost = false
        sessionStartDate = Date()

        observeSession(sessionID: sessionID, musicVM: musicVM)
    }

    // MARK: - 요청 수락 (게스트)
    func acceptRequest(musicVM: RunningMusicViewModel) async {
        guard let session = incomingRequest else { return }
        let player = MPMusicPlayerController.systemMusicPlayer
        let song = currentSongSnapshot(from: musicVM, player: player)
        let position = player.currentPlaybackTime

        RealtimeDBService.shared.updateSessionPlayback(
            sessionID: session.id,
            songStoreID: song.storeID,
            songTitle: song.title,
            artistName: song.artist,
            artworkURL: song.artworkURL,
            artworkData: song.artworkData,
            position: position,
            isPlaying: player.playbackState == .playing
        )
        RealtimeDBService.shared.acceptSession(sessionID: session.id, guestUID: myUID)

        var sourceSession = session
        sourceSession.songStoreID = song.storeID
        sourceSession.songTitle = song.title
        sourceSession.artistName = song.artist
        sourceSession.artworkURL = song.artworkURL
        sourceSession.artworkData = song.artworkData
        sourceSession.playbackPosition = position
        sourceSession.serverTimestamp = Date().timeIntervalSince1970 * 1000
        sourceSession.status = "active"
        sourceSession.isPlaying = player.playbackState == .playing

        activeSession = sourceSession
        isHost = true
        incomingRequest = nil
        lastIncomingRequestID = nil
        sessionStartDate = Date()

        observeSession(sessionID: session.id, musicVM: musicVM)
    }

    // MARK: - 요청 거절
    func declineRequest() {
        guard let session = incomingRequest else { return }
        RealtimeDBService.shared.rejectSession(sessionID: session.id, guestUID: myUID)
        incomingRequest = nil
        lastIncomingRequestID = nil
    }

    // MARK: - 세션 종료
    func endSession() {
        guard let session = activeSession else { return }
        RealtimeDBService.shared.endSession(sessionID: session.id)
        cleanup()
    }

    // MARK: - 음악 소스: 재생 상태 브로드캐스트
    func broadcastIfHost(musicVM: RunningMusicViewModel) {
        guard isHost, let session = activeSession, session.status == "active" else { return }
        let player = MPMusicPlayerController.systemMusicPlayer
        let song = currentSongSnapshot(from: musicVM, player: player)
        RealtimeDBService.shared.updateSessionPlayback(
            sessionID: session.id,
            songStoreID: song.storeID,
            songTitle: song.title,
            artistName: song.artist,
            artworkURL: song.artworkURL,
            artworkData: song.artworkData,
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
        if activeSession?.status != session.status {
            return true
        }
        let player = MPMusicPlayerController.systemMusicPlayer
        let currentStoreID = player.nowPlayingItem?.playbackStoreID ?? ""
        if !session.songStoreID.isEmpty, currentStoreID != session.songStoreID {
            return true
        }
        return activeSession?.songStoreID != session.songStoreID
            || activeSession?.songTitle != session.songTitle
            || activeSession?.artistName != session.artistName
            || activeSession?.artworkURL != session.artworkURL
    }

    private func currentSongSnapshot(
        from musicVM: RunningMusicViewModel,
        player: MPMusicPlayerController
    ) -> (storeID: String, title: String, artist: String, artworkURL: String, artworkData: String) {
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
        let artworkURL = musicSnapshot?.artworkURL ?? ""
        let artworkData = encodedArtworkData(from: musicSnapshot?.artwork)
        return (storeID, title, artist, artworkURL, artworkData)
    }

    private func encodedArtworkData(from image: UIImage?) -> String {
        guard let image else { return "" }
        let targetSize = CGSize(width: 160, height: 160)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.65)?.base64EncodedString() ?? ""
    }

    private func cleanup() {
        RealtimeDBService.shared.stopObservingSession()
        activeSession = nil
        incomingRequest = nil
        isHost = false
        sessionStartDate = nil
        lastIncomingRequestID = nil
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
