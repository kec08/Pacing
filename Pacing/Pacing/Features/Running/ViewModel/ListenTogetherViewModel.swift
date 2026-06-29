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
        let songStoreID = player.nowPlayingItem?.playbackStoreID ?? ""
        let songTitle = musicVM.currentSong?.title ?? ""
        let artistName = musicVM.currentSong?.artistName ?? ""
        let position = player.currentPlaybackTime

        let sessionID = RealtimeDBService.shared.createListenSession(
            hostUID: myUID, hostNickname: myNickname,
            guestUID: runner.id, guestNickname: runner.nickname,
            songStoreID: songStoreID, songTitle: songTitle, artistName: artistName,
            position: position
        )

        activeSession = ListenSession(
            id: sessionID, hostUID: myUID, hostNickname: myNickname,
            guestUID: runner.id, guestNickname: runner.nickname,
            songStoreID: songStoreID, songTitle: songTitle, artistName: artistName,
            playbackPosition: position,
            serverTimestamp: Date().timeIntervalSince1970,
            status: "pending", isPlaying: true
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
        RealtimeDBService.shared.updateSessionPlayback(
            sessionID: session.id,
            songStoreID: player.nowPlayingItem?.playbackStoreID ?? "",
            songTitle: musicVM.currentSong?.title ?? "",
            artistName: musicVM.currentSong?.artistName ?? "",
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
                        // 곡이 바뀌었으면 동기화
                        if self.activeSession?.songStoreID != session.songStoreID {
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
    // MPMediaPropertyPredicate는 playbackStoreID 필터링을 지원하지 않으므로
    // 제목/아티스트 텍스트 매칭으로 라이브러리에서 검색
    private func syncMusic(session: ListenSession) async {
        guard !session.songTitle.isEmpty else { return }
        let player = MPMusicPlayerController.systemMusicPlayer

        let latency = Date().timeIntervalSince1970 - (session.serverTimestamp / 1000.0)
        let targetPosition = max(0, session.playbackPosition + latency)

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
            if session.isPlaying { player.play() }
        }
        // 라이브러리에 없으면 배너에 곡명만 표시
    }

    private func cleanup() {
        RealtimeDBService.shared.stopObservingSession()
        activeSession = nil
        incomingRequest = nil
        isHost = false
        sessionStartDate = nil
    }
}
