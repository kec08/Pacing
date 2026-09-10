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
    private var lastHostedArtworkURL = ""
    private var lastAppliedPlaybackEventID = ""
    private var inFlightPlaybackEventID: String?
    private var activePlaybackSyncToken: UUID?
    private var guestLocallyPaused = false
    private var requestHapticTask: Task<Void, Never>?
    private var profileImageCache: [String: String] = [:]
    private var profileImageLookupTasks: [String: Task<String?, Never>] = [:]
    private var missingProfileImageExpiry: [String: Date] = [:]
    private let missingProfileImageTTL: TimeInterval = 10 * 60

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
        let latestRunner = try? await RealtimeDBService.shared.fetchActiveRunner(uid: runner.id)
        let requestedSongTitle = latestRunner?.songTitle.isEmpty == false
            ? latestRunner!.songTitle
            : runner.songTitle
        let requestedArtist = latestRunner?.artist.isEmpty == false
            ? latestRunner!.artist
            : runner.artist
        let requestedNickname = latestRunner?.nickname.isEmpty == false
            ? latestRunner!.nickname
            : runner.nickname
        let cachedProfileImage = UserDefaults.standard.string(forKey: "profileImageBase64") ?? ""
        let latestProfileImage = (try? await FirestoreService.shared.fetchUserProfile(uid: myUID))?["profileImageBase64"] as? String
        let guestProfileImageBase64 = latestProfileImage?.isEmpty == false ? latestProfileImage! : cachedProfileImage
        if !guestProfileImageBase64.isEmpty {
            UserDefaults.standard.set(guestProfileImageBase64, forKey: "profileImageBase64")
        }
        let storedHostProfileImage = runner.profileImageBase64 ?? ""
        let latestHostProfileImage = storedHostProfileImage.isEmpty
            ? ((try? await FirestoreService.shared.fetchUserProfile(uid: runner.id))?["profileImageBase64"] as? String ?? "")
            : storedHostProfileImage
        let playbackEventID = UUID().uuidString
        let sessionID = RealtimeDBService.shared.createListenSession(
            hostUID: runner.id, hostNickname: requestedNickname,
            hostProfileImageBase64: latestHostProfileImage,
            guestUID: myUID, guestNickname: myNickname,
            guestProfileImageBase64: guestProfileImageBase64,
            songStoreID: "",
            songTitle: requestedSongTitle,
            artistName: requestedArtist,
            artworkURL: "",
            artworkData: "",
            playbackEventID: playbackEventID,
            position: 0,
            isPlaying: false
        )

        activeSession = ListenSession(
            id: sessionID, hostUID: runner.id, hostNickname: requestedNickname,
            hostProfileImageBase64: latestHostProfileImage,
            guestUID: myUID, guestNickname: myNickname,
            guestProfileImageBase64: guestProfileImageBase64,
            songStoreID: "",
            songTitle: requestedSongTitle,
            artistName: requestedArtist,
            artworkURL: "",
            artworkData: "",
            playbackEventID: playbackEventID,
            playbackPosition: 0,
            serverTimestamp: Date().timeIntervalSince1970 * 1000,
            status: "pending", isPlaying: false
        )
        isHost = false
        sessionStartDate = Date()

        observeSession(sessionID: sessionID, musicVM: musicVM)
    }

    // MARK: - 요청 수락 (호스트)
    func acceptRequest(musicVM: RunningMusicViewModel) async {
        guard let session = incomingRequest else { return }
        requestHapticTask?.cancel()
        requestHapticTask = nil
        let player = MPMusicPlayerController.systemMusicPlayer
        let song = currentSongSnapshot(from: musicVM, player: player)
        let position = musicVM.isUsingApplicationPlayer
            ? musicVM.currentPlaybackTime
            : player.currentPlaybackTime

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
        sourceSession.isPlaying = musicVM.isUsingApplicationPlayer
            ? musicVM.isPlaying
            : player.playbackState == .playing

        RealtimeDBService.shared.updateSessionPlayback(
            sessionID: session.id,
            songStoreID: song.storeID,
            songTitle: song.title,
            artistName: song.artist,
            artworkURL: song.artworkURL,
            artworkData: song.artworkData,
            playbackEventID: sourceSession.playbackEventID,
            position: position,
            isPlaying: sourceSession.isPlaying
        )
        RealtimeDBService.shared.acceptSession(sessionID: session.id, hostUID: myUID)

        activeSession = sourceSession
        isHost = true
        hostPlaybackEventID = sourceSession.playbackEventID
        lastHostedTrackKey = [song.storeID, song.title, song.artist].joined(separator: "|")
        lastHostedArtworkURL = song.artworkURL
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
    func broadcastSeekIfHost(musicVM: RunningMusicViewModel) {
        guard isHost, activeSession?.status == "active" else { return }
        // 위치 이동은 같은 곡이어도 게스트가 반드시 재동기화해야 하므로
        // 일반 주기 브로드캐스트와 구분되는 이벤트 ID를 발급합니다.
        hostPlaybackEventID = UUID().uuidString
        broadcastIfHost(musicVM: musicVM)
    }

    /// 게스트는 자신의 기기에서만 재생을 멈추고, 다시 재생할 때 호스트 위치로 보정합니다.
    func toggleGuestPlayback(musicVM: RunningMusicViewModel) async {
        guard !isHost, activeSession?.status == "active" else { return }

        if musicVM.isPlaying {
            guestLocallyPaused = true
            await musicVM.togglePlayPause()
            return
        }

        guestLocallyPaused = false
        if let session = activeSession {
            await syncMusic(session: session, musicVM: musicVM)
        } else {
            await musicVM.togglePlayPause()
        }
    }

    func broadcastIfHost(musicVM: RunningMusicViewModel) {
        guard isHost, let session = activeSession, session.status == "active" else { return }
        let player = MPMusicPlayerController.systemMusicPlayer
        // 같이 듣기 호스트의 기준 플레이어는 러닝 화면과 동일한
        // RunningMusicViewModel입니다. 시스템 플레이어 상태를 섞으면
        // 호스트는 정지했는데 세션 위치가 계속 증가하는 문제가 생깁니다.
        let playbackPosition = musicVM.currentPlaybackTime
        let isPlaying = musicVM.isPlaying
        let metadata = currentSongSnapshot(from: musicVM, player: player, includesArtworkData: false)
        let trackKey = [metadata.storeID, metadata.title, metadata.artist].joined(separator: "|")
        let isTrackTransition = !trackKey.isEmpty && trackKey != lastHostedTrackKey
        let isArtworkUpdate = isTrackTransition || metadata.artworkURL != lastHostedArtworkURL

        // 타이머에 의한 위치 갱신은 같은 이벤트 ID를 유지합니다. 실제 곡 전환만 새 이벤트로
        // 기록해 게스트가 매초 큐를 재구성하지 않도록 합니다.
        if isTrackTransition {
            lastHostedTrackKey = trackKey
            hostPlaybackEventID = UUID().uuidString
        }
        let song = isArtworkUpdate
            ? currentSongSnapshot(from: musicVM, player: player)
            : metadata
        if isArtworkUpdate {
            lastHostedArtworkURL = song.artworkURL
        }
        RealtimeDBService.shared.updateSessionPlayback(
            sessionID: session.id,
            songStoreID: song.storeID,
            songTitle: song.title,
            artistName: song.artist,
            artworkURL: isArtworkUpdate ? song.artworkURL : nil,
            artworkData: isArtworkUpdate ? song.artworkData : nil,
            playbackEventID: hostPlaybackEventID,
            position: playbackPosition,
            isPlaying: isPlaying
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
                        let previousSession = self.activeSession
                        // 이후의 위치 갱신이 같은 전환 이벤트를 중복 처리하지 않도록 먼저 반영합니다.
                        self.activeSession = resolvedSession
                        // 곡·재생 상태뿐 아니라, 같은 이벤트에서 늦게 보강되는 앨범 커버도
                        // 게스트 큐 캐시에 반영해야 음악 시트가 placeholder에 머물지 않습니다.
                        if self.shouldSyncMusic(
                            with: resolvedSession,
                            previousSession: previousSession,
                            musicVM: musicVM
                        ) {
                            await self.syncMusic(session: resolvedSession, musicVM: musicVM)
                        }
                        guard self.activeSession?.playbackEventID == resolvedSession.playbackEventID else {
                            return
                        }
                        // ApplicationMusicPlayer 세션은 syncMusic에서 재생 상태까지 반영한다.
                        // 시스템 플레이어를 다시 조작하면 게스트 큐가 매 위치 갱신마다
                        // 다른 곡으로 재구성될 수 있어 legacy 재생에서만 사용한다.
                        if !musicVM.isUsingApplicationPlayer {
                            let player = MPMusicPlayerController.systemMusicPlayer
                            if resolvedSession.isPlaying && player.playbackState != .playing {
                                player.play()
                            } else if !resolvedSession.isPlaying && player.playbackState == .playing {
                                player.pause()
                            }
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
    private func syncMusic(session: ListenSession, musicVM: RunningMusicViewModel) async {
        guard !session.songStoreID.isEmpty || !session.songTitle.isEmpty else { return }
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

        // 러닝 화면은 ApplicationMusicPlayer를 사용하므로, 먼저 동일한 큐에서
        // 곡을 전환해야 노래바와 같이 듣기 재생 곡이 어긋나지 않습니다.
        if await musicVM.syncToListenSession(
            songStoreID: session.songStoreID,
            title: session.songTitle,
            artist: session.artistName,
            artworkURL: session.artworkURL,
            position: targetPosition,
            isPlaying: session.isPlaying && !guestLocallyPaused
        ) {
            lastAppliedPlaybackEventID = eventID
            return
        }

        // 러닝 앱의 주 재생기는 ApplicationMusicPlayer다. 카탈로그에서 곡을 찾지
        // 못한 경우 systemMusicPlayer 큐를 반복 재구성하지 않아 다른 곡이 계속
        // 로딩되는 현상을 막는다. 다음 실제 곡 전환 이벤트에서 다시 시도한다.
        lastAppliedPlaybackEventID = eventID
        print("[ListenTogether] application player sync failed: \(session.songTitle) - \(session.artistName)")
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

    private func shouldSyncMusic(
        with session: ListenSession,
        previousSession: ListenSession?,
        musicVM: RunningMusicViewModel
    ) -> Bool {
        if previousSession?.status != session.status {
            return true
        }
        let artworkChanged = previousSession?.artworkURL != session.artworkURL
            || previousSession?.artworkData != session.artworkData
        if artworkChanged {
            return true
        }
        let eventID = effectivePlaybackEventID(for: session)
        if inFlightPlaybackEventID == eventID {
            return false
        }
        if let snapshot = musicVM.currentSongSnapshot() {
            let isSameSong = (!session.songStoreID.isEmpty && snapshot.songStoreID == session.songStoreID)
                || (snapshot.title == session.songTitle && snapshot.artistName == session.artistName)
            if !isSameSong {
                return true
            }
            if guestLocallyPaused {
                return false
            }
            let latency = Date().timeIntervalSince1970 - (session.serverTimestamp / 1000.0)
            let expectedPosition = max(0, session.playbackPosition + latency)
            if abs(musicVM.currentPlaybackTime - expectedPosition) > 2.5 {
                return true
            }
            if session.isPlaying != musicVM.isPlaying {
                return true
            }
            return lastAppliedPlaybackEventID != eventID
        }

        let player = MPMusicPlayerController.systemMusicPlayer
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
        let storeID = musicSnapshot?.songStoreID.nonEmpty
            ?? mediaItem?.playbackStoreID.nonEmpty
            ?? ""
        let title = musicSnapshot?.title.nonEmpty
            ?? mediaItem?.title?.nonEmpty
            ?? ""
        let artist = musicSnapshot?.artistName.nonEmpty
            ?? mediaItem?.artist?.nonEmpty
            ?? ""
        let artworkURL = musicSnapshot?.artworkURL ?? ""
        // ApplicationMusicPlayer와 시스템 플레이어는 서로 다른 큐를 가질 수 있습니다.
        // 앱 플레이어를 사용하는 동안 시스템 플레이어의 이전 커버를 세션에 넣으면
        // 게스트가 곡과 무관한 동일한 고정 이미지만 계속 표시하게 됩니다.
        let mediaArtwork = musicVM.isUsingApplicationPlayer
            ? nil
            : mediaItem?.artwork?.image(at: CGSize(width: 320, height: 320))
        let artworkData = includesArtworkData
            ? encodedArtworkData(from: musicSnapshot?.artwork ?? mediaArtwork)
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
        guestLocallyPaused = false
        lastHostedTrackKey = ""
        lastHostedArtworkURL = ""
    }

    private func resolvedProfileImages(for session: ListenSession) async -> ListenSession {
        var resolved = session
        let participantIDs = [session.hostUID, session.guestUID]

        for uid in participantIDs where !uid.isEmpty && resolved.profileImageBase64(for: uid).isEmpty {
            let image = await profileImage(for: uid)

            guard let image, !image.isEmpty else { continue }
            if uid == resolved.hostUID {
                resolved.hostProfileImageBase64 = image
            } else if uid == resolved.guestUID {
                resolved.guestProfileImageBase64 = image
            }
        }

        return resolved
    }

    private func profileImage(for uid: String) async -> String? {
        if let cachedImage = profileImageCache[uid], !cachedImage.isEmpty {
            return cachedImage
        }

        if uid == myUID,
           let localImage = UserDefaults.standard.string(forKey: "profileImageBase64"),
           !localImage.isEmpty {
            profileImageCache[uid] = localImage
            return localImage
        }

        if let expiry = missingProfileImageExpiry[uid] {
            if expiry > Date() { return nil }
            missingProfileImageExpiry.removeValue(forKey: uid)
        }

        if let lookupTask = profileImageLookupTasks[uid] {
            return await lookupTask.value
        }

        let lookupTask = Task<String?, Never> {
            (try? await FirestoreService.shared.fetchUserProfile(uid: uid))?["profileImageBase64"] as? String
        }
        profileImageLookupTasks[uid] = lookupTask
        let image = await lookupTask.value
        profileImageLookupTasks.removeValue(forKey: uid)

        if let image, !image.isEmpty {
            profileImageCache[uid] = image
            return image
        }

        missingProfileImageExpiry[uid] = Date().addingTimeInterval(missingProfileImageTTL)
        return nil
    }

    private func playRequestHapticPattern() {
        requestHapticTask?.cancel()
        requestHapticTask = Task { @MainActor in
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            for _ in 0..<2 {
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
            }
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
