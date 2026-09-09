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
    private var hostBroadcastTimer: AnyCancellable?
    private weak var hostMusicViewModel: RunningMusicViewModel?
    private var hostPlaybackEventID = UUID().uuidString
    private var lastHostedTrackKey = ""
    private var lastAppliedPlaybackEventID = ""
    private var inFlightPlaybackEventID: String?
    private var activePlaybackSyncToken: UUID?
    private var requestHapticTask: Task<Void, Never>?

    // MARK: - 요청 수신 감지 시작
    func startObservingRequests() {
        RealtimeDBService.shared.observeIncomingRequests(uid: myUID) { [weak self] session in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let session = session, session.status == "pending" {
                    if self.lastIncomingRequestID != session.id {
                        self.lastIncomingRequestID = session.id
                        self.playRequestHapticPattern()
                    }
                    self.incomingRequest = await self.resolvedProfileImages(for: session)
                }
            }
        }
    }

    func stopObservingRequests() {
        RealtimeDBService.shared.stopObservingIncomingRequests(uid: myUID)
        requestHapticTask?.cancel()
        requestHapticTask = nil
    }

    // MARK: - 같이 듣기 요청 보내기
    func sendRequest(to runner: NearbyRunner, musicVM: RunningMusicViewModel) async {
        let cachedProfileImage = UserDefaults.standard.string(forKey: "profileImageBase64") ?? ""
        let latestProfileImage = (try? await FirestoreService.shared.fetchUserProfile(uid: myUID))?["profileImageBase64"] as? String
        let hostProfileImageBase64 = latestProfileImage?.isEmpty == false ? latestProfileImage! : cachedProfileImage
        if !hostProfileImageBase64.isEmpty {
            UserDefaults.standard.set(hostProfileImageBase64, forKey: "profileImageBase64")
        }
        let storedGuestProfileImage = runner.profileImageBase64 ?? ""
        let latestGuestProfileImage = storedGuestProfileImage.isEmpty
            ? ((try? await FirestoreService.shared.fetchUserProfile(uid: runner.id))?["profileImageBase64"] as? String ?? "")
            : storedGuestProfileImage
        let requestSong = currentSongSnapshot(
            from: musicVM,
            player: MPMusicPlayerController.systemMusicPlayer
        )
        let sessionID = RealtimeDBService.shared.createListenSession(
            hostUID: myUID, hostNickname: myNickname,
            hostProfileImageBase64: hostProfileImageBase64,
            guestUID: runner.id, guestNickname: runner.nickname,
            guestProfileImageBase64: latestGuestProfileImage,
            songStoreID: requestSong.storeID,
            songTitle: requestSong.title.isEmpty ? runner.songTitle : requestSong.title,
            artistName: requestSong.artist.isEmpty ? runner.artist : requestSong.artist,
            artworkURL: requestSong.artworkURL,
            artworkData: requestSong.artworkData,
            position: 0
        )

        activeSession = ListenSession(
            id: sessionID, hostUID: myUID, hostNickname: myNickname,
            hostProfileImageBase64: hostProfileImageBase64,
            guestUID: runner.id, guestNickname: runner.nickname,
            guestProfileImageBase64: latestGuestProfileImage,
            songStoreID: requestSong.storeID,
            songTitle: requestSong.title.isEmpty ? runner.songTitle : requestSong.title,
            artistName: requestSong.artist.isEmpty ? runner.artist : requestSong.artist,
            artworkURL: requestSong.artworkURL,
            artworkData: requestSong.artworkData,
            playbackEventID: UUID().uuidString,
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
        requestHapticTask?.cancel()
        requestHapticTask = nil
        let player = MPMusicPlayerController.systemMusicPlayer
        let song = currentSongSnapshot(from: musicVM, player: player)
        let position = player.currentPlaybackTime

        var sourceSession = await resolvedProfileImages(for: session)
        sourceSession.songStoreID = song.storeID
        sourceSession.songTitle = song.title
        sourceSession.artistName = song.artist
        sourceSession.artworkURL = song.artworkURL
        sourceSession.artworkData = song.artworkData
        sourceSession.playbackEventID = UUID().uuidString
        sourceSession.playbackPosition = position
        sourceSession.serverTimestamp = Date().timeIntervalSince1970 * 1000
        sourceSession.status = "active"
        sourceSession.isPlaying = player.playbackState == .playing

        RealtimeDBService.shared.updateSessionPlayback(
            sessionID: session.id,
            songStoreID: song.storeID,
            songTitle: song.title,
            artistName: song.artist,
            artworkURL: song.artworkURL,
            artworkData: song.artworkData,
            playbackEventID: sourceSession.playbackEventID,
            position: position,
            isPlaying: player.playbackState == .playing
        )
        RealtimeDBService.shared.acceptSession(sessionID: session.id, guestUID: myUID)

        activeSession = sourceSession
        isHost = true
        hostPlaybackEventID = sourceSession.playbackEventID
        lastHostedTrackKey = [song.storeID, song.title, song.artist].joined(separator: "|")
        incomingRequest = nil
        lastIncomingRequestID = nil
        sessionStartDate = Date()
        startHostBroadcasting(with: musicVM)

        observeSession(sessionID: session.id, musicVM: musicVM)
    }

    // MARK: - 요청 거절
    func declineRequest() {
        guard let session = incomingRequest else { return }
        requestHapticTask?.cancel()
        requestHapticTask = nil
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
        let metadata = currentSongSnapshot(from: musicVM, player: player, includesArtworkData: false)
        let trackKey = [metadata.storeID, metadata.title, metadata.artist].joined(separator: "|")
        let isTrackTransition = !trackKey.isEmpty && trackKey != lastHostedTrackKey

        // 타이머에 의한 위치 갱신은 같은 이벤트 ID를 유지합니다. 실제 곡 전환만 새 이벤트로
        // 기록해 게스트가 매초 큐를 재구성하지 않도록 합니다.
        if isTrackTransition {
            lastHostedTrackKey = trackKey
            hostPlaybackEventID = UUID().uuidString
        }
        let song = isTrackTransition
            ? currentSongSnapshot(from: musicVM, player: player)
            : metadata
        RealtimeDBService.shared.updateSessionPlayback(
            sessionID: session.id,
            songStoreID: song.storeID,
            songTitle: song.title,
            artistName: song.artist,
            artworkURL: isTrackTransition ? song.artworkURL : nil,
            artworkData: isTrackTransition ? song.artworkData : nil,
            playbackEventID: hostPlaybackEventID,
            position: player.currentPlaybackTime,
            isPlaying: player.playbackState == .playing
        )
    }

    // MARK: - 세션 구독
    private func observeSession(sessionID: String, musicVM: RunningMusicViewModel) {
        RealtimeDBService.shared.observeSession(sessionID: sessionID) { [weak self] session in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let resolvedSession = await self.resolvedProfileImages(for: session)

                switch resolvedSession.status {
                case "rejected", "ended":
                    self.cleanup()
                case "active":
                    if self.isHost {
                        self.startHostBroadcasting(with: musicVM)
                    }
                    if !self.isHost {
                        // 이후의 위치 갱신이 같은 전환 이벤트를 중복 처리하지 않도록 먼저 반영합니다.
                        self.activeSession = resolvedSession
                        // 곡이 바뀌었거나 아직 같은 곡을 재생 중이 아니면 동기화
                        if self.shouldSyncMusic(with: resolvedSession) {
                            await self.syncMusic(session: resolvedSession)
                        }
                        guard self.activeSession?.playbackEventID == resolvedSession.playbackEventID else {
                            return
                        }
                        // 재생/일시정지 동기화
                        let player = MPMusicPlayerController.systemMusicPlayer
                        if resolvedSession.isPlaying && player.playbackState != .playing {
                            player.play()
                        } else if !resolvedSession.isPlaying && player.playbackState == .playing {
                            player.pause()
                        }
                    }
                    self.activeSession = resolvedSession
                default:
                    self.activeSession = resolvedSession
                }
            }
        }
    }

    // MARK: - MusicKit 싱크 (게스트)
    private func syncMusic(session: ListenSession) async {
        guard !session.songStoreID.isEmpty || !session.songTitle.isEmpty else { return }
        let player = MPMusicPlayerController.systemMusicPlayer
        let eventID = effectivePlaybackEventID(for: session)

        // Firebase의 위치 보정 값은 매초 바뀐다. 동일한 곡 전환을 준비 중이면 새 작업을 시작하지 않는다.
        guard inFlightPlaybackEventID != eventID else { return }

        let syncToken = UUID()
        inFlightPlaybackEventID = eventID
        activePlaybackSyncToken = syncToken
        defer {
            if activePlaybackSyncToken == syncToken {
                inFlightPlaybackEventID = nil
            }
        }

        let latency = Date().timeIntervalSince1970 - (session.serverTimestamp / 1000.0)
        let targetPosition = max(0, session.playbackPosition + latency)

        if isCurrentTrackMatching(session: session, player: player) {
            syncCurrentTrackPosition(
                targetPosition: targetPosition,
                isPlaying: session.isPlaying,
                player: player
            )
            lastAppliedPlaybackEventID = eventID
            return
        }

        if await syncByStoreID(
            session: session,
            targetPosition: targetPosition,
            player: player,
            syncToken: syncToken
        ) {
            lastAppliedPlaybackEventID = eventID
            return
        }

        if await syncByLibrarySearch(
            session: session,
            targetPosition: targetPosition,
            player: player,
            syncToken: syncToken
        ) {
            lastAppliedPlaybackEventID = eventID
        }
    }

    private func syncByStoreID(
        session: ListenSession,
        targetPosition: TimeInterval,
        player: MPMusicPlayerController,
        syncToken: UUID
    ) async -> Bool {
        guard !session.songStoreID.isEmpty else { return false }
        player.setQueue(with: [session.songStoreID])
        do {
            try await player.prepareToPlay()
            guard isCurrentPlaybackSync(syncToken) else { return false }
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
        player: MPMusicPlayerController,
        syncToken: UUID
    ) async -> Bool {
        guard !session.songTitle.isEmpty else { return false }
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
            guard isCurrentPlaybackSync(syncToken) else { return false }
            player.currentPlaybackTime = targetPosition
            if session.isPlaying {
                player.play()
            } else {
                player.pause()
            }
            return true
        } else {
            print("[ListenTogether] library fallback failed: \(session.songTitle) - \(session.artistName)")
            return false
        }
    }

    private func shouldSyncMusic(with session: ListenSession) -> Bool {
        if activeSession?.status != session.status {
            return true
        }
        let player = MPMusicPlayerController.systemMusicPlayer
        let eventID = effectivePlaybackEventID(for: session)
        if inFlightPlaybackEventID == eventID {
            return false
        }
        let currentStoreID = player.nowPlayingItem?.playbackStoreID ?? ""
        if !session.songStoreID.isEmpty, currentStoreID != session.songStoreID {
            return true
        }
        let latency = Date().timeIntervalSince1970 - (session.serverTimestamp / 1000.0)
        let expectedPosition = max(0, session.playbackPosition + latency)
        let positionGap = abs(player.currentPlaybackTime - expectedPosition)
        if positionGap > 1.5 {
            return true
        }
        if session.isPlaying != (player.playbackState == .playing) {
            return true
        }
        return lastAppliedPlaybackEventID != eventID
            || activeSession?.songStoreID != session.songStoreID
            || activeSession?.songTitle != session.songTitle
            || activeSession?.artistName != session.artistName
            || activeSession?.artworkURL != session.artworkURL
            || activeSession?.artworkData != session.artworkData
    }

    private func currentSongSnapshot(
        from musicVM: RunningMusicViewModel,
        player: MPMusicPlayerController,
        includesArtworkData: Bool = true
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
        let artworkData = includesArtworkData
            ? encodedArtworkData(from: musicSnapshot?.artwork)
            : ""
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

    private func isCurrentTrackMatching(
        session: ListenSession,
        player: MPMusicPlayerController
    ) -> Bool {
        let currentStoreID = player.nowPlayingItem?.playbackStoreID ?? ""
        if !session.songStoreID.isEmpty && currentStoreID == session.songStoreID {
            return true
        }

        let currentTitle = player.nowPlayingItem?.title ?? ""
        let currentArtist = player.nowPlayingItem?.artist ?? ""
        return !session.songTitle.isEmpty
            && currentTitle == session.songTitle
            && currentArtist == session.artistName
    }

    private func syncCurrentTrackPosition(
        targetPosition: TimeInterval,
        isPlaying: Bool,
        player: MPMusicPlayerController
    ) {
        if abs(player.currentPlaybackTime - targetPosition) > 1.5 {
            player.currentPlaybackTime = targetPosition
        }

        if isPlaying && player.playbackState != .playing {
            player.play()
        } else if !isPlaying && player.playbackState == .playing {
            player.pause()
        }
    }

    private func effectivePlaybackEventID(for session: ListenSession) -> String {
        if !session.playbackEventID.isEmpty {
            return session.playbackEventID
        }
        // 이전 세션 데이터와의 호환을 위해 이벤트 ID가 없는 경우에만 기존 스냅샷을 사용합니다.
        return "legacy-\(session.songStoreID)-\(session.songTitle)-\(Int(session.serverTimestamp))"
    }

    private func isCurrentPlaybackSync(_ token: UUID) -> Bool {
        activePlaybackSyncToken == token && activeSession?.status == "active"
    }

    private func startHostBroadcasting(with musicVM: RunningMusicViewModel) {
        hostMusicViewModel = musicVM
        guard hostBroadcastTimer == nil else { return }

        hostBroadcastTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let musicVM = self.hostMusicViewModel else { return }
                self.broadcastIfHost(musicVM: musicVM)
            }
    }

    private func stopHostBroadcasting() {
        hostBroadcastTimer?.cancel()
        hostBroadcastTimer = nil
        hostMusicViewModel = nil
    }

    private func cleanup() {
        requestHapticTask?.cancel()
        requestHapticTask = nil
        stopHostBroadcasting()
        RealtimeDBService.shared.stopObservingSession()
        activeSession = nil
        incomingRequest = nil
        isHost = false
        sessionStartDate = nil
        lastIncomingRequestID = nil
        activePlaybackSyncToken = nil
        inFlightPlaybackEventID = nil
        lastAppliedPlaybackEventID = ""
        lastHostedTrackKey = ""
    }

    private func resolvedProfileImages(for session: ListenSession) async -> ListenSession {
        var resolved = session
        let participantIDs = [session.hostUID, session.guestUID]

        for uid in participantIDs where !uid.isEmpty && resolved.profileImageBase64(for: uid).isEmpty {
            let cachedImage = uid == myUID
                ? UserDefaults.standard.string(forKey: "profileImageBase64")
                : nil
            let image: String?
            if let cachedImage, !cachedImage.isEmpty {
                image = cachedImage
            } else {
                image = (try? await FirestoreService.shared.fetchUserProfile(uid: uid))?["profileImageBase64"] as? String
            }

            guard let image, !image.isEmpty else { continue }
            if uid == resolved.hostUID {
                resolved.hostProfileImageBase64 = image
            } else if uid == resolved.guestUID {
                resolved.guestProfileImageBase64 = image
            }
        }

        return resolved
    }

    private func playRequestHapticPattern() {
        requestHapticTask?.cancel()
        requestHapticTask = Task { @MainActor in
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            for _ in 0..<2 {
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
