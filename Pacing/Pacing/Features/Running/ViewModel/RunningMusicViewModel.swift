import SwiftUI
import MusicKit
import MediaPlayer
import Combine
import UIKit

struct PlayerSongSnapshot: Equatable {
    let title: String
    let artistName: String
    let songStoreID: String
    let artworkURL: String?
    let artwork: UIImage?

    static func == (lhs: PlayerSongSnapshot, rhs: PlayerSongSnapshot) -> Bool {
        lhs.title == rhs.title
            && lhs.artistName == rhs.artistName
            && lhs.songStoreID == rhs.songStoreID
            && lhs.artworkURL == rhs.artworkURL
    }
}

@MainActor
final class RunningMusicViewModel: ObservableObject {
    @Published var authStatus: MusicAuthorization.Status = .notDetermined
    @Published var playlists: [Playlist] = []
    @Published var currentSong: Song? = nil
    @Published var currentSongIndex: Int = 0
    @Published var queueSongs: [Song] = []
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var isGoingForward: Bool = true
    @Published var nowPlayingSnapshot: PlayerSongSnapshot? = nil
    @Published private(set) var displayPlaybackTime: TimeInterval = 0
    @Published private(set) var applicationPlaybackDuration: TimeInterval = 0
    @Published private(set) var currentPlaylistName: String? = nil
    @Published private(set) var queueArtworkURLsBySongID: [String: String] = [:]
    @Published private(set) var playlistArtworkURLsByPlaylistID: [String: String] = [:]

    private let player = MPMusicPlayerController.systemMusicPlayer
    private let applicationPlayer = ApplicationMusicPlayer.shared
    private let musicService = AppleMusicRecommendationService.shared
    private let playlistRetryDelays: [UInt64] = [500_000_000, 1_200_000_000, 2_500_000_000]
    private var isManualSeeking: Bool = false
    private var seekSyncTask: Task<Void, Never>?
    private var playbackClock: AnyCancellable?
    private var optimisticPlaybackBaseTime: TimeInterval?
    private var optimisticPlaybackStartedAt: Date?
    private var pendingTrackPersistentID: MPMediaEntityPersistentID?
    private var activePlaylistLoadID: UUID?
    private var resolvingSongArtworkIDs: Set<String> = []
    private var resolvedApplicationSongsByEntryID: [String: Song] = [:]
    private var resolvingApplicationEntryIDs: Set<String> = []
    private var resolvingApplicationArtworkIDs: Set<String> = []
    // 재생 중인 플레이리스트의 MPMediaItem 캐시
    private var cachedMediaItems: [MPMediaItem] = []
    private var notificationObservers: [NSObjectProtocol] = []
    private var applicationQueueObserver: AnyCancellable?
    private var applicationStateObserver: AnyCancellable?
    private var applicationPlaybackPoller: AnyCancellable?

    init() {
        observePlaybackState()
        startPlaybackClock()
    }

    deinit {
        playbackClock?.cancel()
        seekSyncTask?.cancel()
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        player.endGeneratingPlaybackNotifications()
    }

    // MARK: - 권한 요청
    func requestAuthorization() async {
        authStatus = await musicService.requestAuthorizationIfNeeded()
        if authStatus == .authorized {
            await fetchPlaylists()
            syncCurrentState()
        }
    }

    // MARK: - 플레이리스트 fetch
    func fetchPlaylists() async {
        authStatus = await musicService.requestAuthorizationIfNeeded()
        guard authStatus == .authorized else {
            playlists = []
            playlistArtworkURLsByPlaylistID = [:]
            return
        }

        isLoading = true
        defer { isLoading = false }

        for attempt in 0 ... playlistRetryDelays.count {
            do {
                let fetchedPlaylists = try await musicService.fetchLibraryPlaylists()
                playlists = fetchedPlaylists
                loadPlaylistArtworkURLsInBackground(for: fetchedPlaylists)
                return
            } catch {
                guard attempt < playlistRetryDelays.count else { break }
                try? await Task.sleep(nanoseconds: playlistRetryDelays[attempt])
            }
        }

        playlistArtworkURLsByPlaylistID = [:]
    }

    // MARK: - 플레이리스트 재생
    func play(playlist: Playlist) async {
        let loadID = UUID()
        activePlaylistLoadID = loadID
        currentPlaylistName = playlist.name
        queueSongs = []
        queueArtworkURLsBySongID = [:]
        currentSong = nil
        currentSongIndex = 0

        // 음악 탭에서 ApplicationMusicPlayer가 살아 있으면 해당 상태가 우선 표시된다.
        // 러닝 플레이리스트 시작 시 이를 멈춰 현재 재생 항목의 기준을 하나로 유지한다.
        applicationPlayer.pause()
        cachedMediaItems = []
        isLoading = true
        defer { isLoading = false }

        guard let loaded = try? await playlist.with([.tracks]),
              activePlaylistLoadID == loadID
        else { return }

        let loadedSongs = loaded.tracks?.compactMap { track -> Song? in
            if case .song(let song) = track { return song }
            return nil
        } ?? []
        guard !loadedSongs.isEmpty else { return }

        // 러닝과 음악 탭 모두 ApplicationMusicPlayer만 사용한다. 두 플레이어를 섞으면
        // 같은 시점에 서로 다른 큐를 읽어 제목·커버·제어가 분리된다.
        queueSongs = loadedSongs
        currentSong = loadedSongs[0]
        currentSongIndex = 0
        musicService.playbackContext.configure(songs: loadedSongs)
        applicationPlayer.queue = .init(for: loadedSongs)
        NotificationCenter.default.post(name: .applicationMusicPlayerQueueDidChange, object: applicationPlayer)
        try? await applicationPlayer.prepareToPlay()
        try? await applicationPlayer.play()
        syncCurrentState()
    }

    // MARK: - 인덱스로 곡 직접 이동 (캐시된 아이템 활용)
    func play(at index: Int) async {
        guard queueSongs.indices.contains(index) else { return }
        let targetSong = queueSongs[index]
        currentSongIndex = index
        currentSong = targetSong
        musicService.playbackContext.configure(songs: queueSongs, startingAt: targetSong)
        applicationPlayer.queue = .init(for: queueSongs, startingAt: targetSong)
        NotificationCenter.default.post(name: .applicationMusicPlayerQueueDidChange, object: applicationPlayer)
        try? await applicationPlayer.prepareToPlay()
        try? await applicationPlayer.play()
        syncCurrentState()
    }

    // MARK: - 재생 시간
    var currentPlaybackTime: TimeInterval { displayPlaybackTime }
    var playbackDuration: TimeInterval {
        isUsingApplicationPlayer ? applicationPlaybackDuration : player.nowPlayingItem?.playbackDuration ?? 0
    }

    var displaySongTitle: String {
        nowPlayingSnapshot?.title ?? currentSong?.title ?? "플레이리스트를 선택하세요"
    }

    var displayArtistName: String {
        nowPlayingSnapshot?.artistName ?? currentSong?.artistName ?? "Apple Music"
    }

    var hasDisplaySong: Bool {
        currentSong != nil || nowPlayingSnapshot != nil
    }

    var canSkipToPrevious: Bool {
        if isUsingApplicationPlayer { return true }
        return currentSongIndex > 0 && currentSongIndex < cachedMediaItems.count
    }

    var canSkipToNext: Bool {
        if isUsingApplicationPlayer { return true }
        return currentSongIndex >= 0 && currentSongIndex + 1 < cachedMediaItems.count
    }

    // 음악 탭에서 시작한 ApplicationMusicPlayer 재생은 엔트리 메타데이터가
    // 가장 최신이므로, 러닝 시트도 동일한 스냅샷을 우선 렌더링한다.
    var isUsingApplicationPlayer: Bool {
        applicationPlayer.queue.currentEntry != nil && applicationPlayer.state.playbackStatus != .stopped
    }

    func currentSongSnapshot() -> PlayerSongSnapshot? {
        if isUsingApplicationPlayer,
           let entry = applicationPlayer.queue.currentEntry {
            let song = applicationSong(from: entry)
            let resolvedArtwork = nowPlayingSnapshot?.songStoreID == entry.id
                ? nowPlayingSnapshot?.artwork
                : nil
            return PlayerSongSnapshot(
                title: entry.title,
                artistName: entry.subtitle ?? "Apple Music",
                songStoreID: entry.id,
                artworkURL: entry.artwork?.url(width: 900, height: 900)?.absoluteString
                    ?? song?.artwork?.url(width: 900, height: 900)?.absoluteString,
                artwork: resolvedArtwork
            )
        }

        // 시스템 플레이어의 전환 알림보다 UI 갱신이 먼저 일어나는 짧은 구간에는
        // 사용자가 선택한 다음 곡 정보를 우선 표시해 커버·제목이 엇갈리지 않게 한다.
        if pendingTrackPersistentID != nil, let nowPlayingSnapshot {
            return nowPlayingSnapshot
        }

        if let item = player.nowPlayingItem, !item.playbackStoreID.isEmpty {
            return PlayerSongSnapshot(
                title: item.title ?? currentSong?.title ?? "",
                artistName: item.artist ?? currentSong?.artistName ?? "Apple Music",
                songStoreID: item.playbackStoreID,
                artworkURL: artworkURL(for: currentSong),
                artwork: item.artwork?.image(at: CGSize(width: 320, height: 320))
            )
        }
        if let currentSong {
            return PlayerSongSnapshot(
                title: currentSong.title,
                artistName: currentSong.artistName,
                songStoreID: "\(currentSong.id)",
                artworkURL: artworkURL(for: currentSong),
                artwork: nil
            )
        }
        return nowPlayingSnapshot
    }

    func artworkURL(for song: Song?) -> String? {
        guard let song else { return nil }

        if let artworkURL = song.artwork?.url(width: 900, height: 900)?.absoluteString,
           !artworkURL.isEmpty {
            return artworkURL
        }

        return queueArtworkURLsBySongID["\(song.id)"]
    }

    /// 목록에 실제로 보이는 곡만 커버를 보강한다. 전체 곡을 한 번에 검색하지 않아
    /// 긴 플레이리스트에서도 네트워크 요청과 메모리 사용량이 급증하지 않는다.
    func loadArtworkURLIfNeeded(for song: Song) async {
        let songID = "\(song.id)"
        let loadID = activePlaylistLoadID
        guard artworkURL(for: song) == nil,
              queueArtworkURLsBySongID[songID] == nil,
              !resolvingSongArtworkIDs.contains(songID),
              loadID != nil
        else { return }

        resolvingSongArtworkIDs.insert(songID)
        let resolvedArtworkURLs = await musicService.resolvedArtworkURLs(for: [song])
        resolvingSongArtworkIDs.remove(songID)
        guard activePlaylistLoadID == loadID,
              let resolvedArtworkURL = resolvedArtworkURLs[songID]
        else { return }
        queueArtworkURLsBySongID[songID] = resolvedArtworkURL
    }

    func artworkURL(for playlist: Playlist) -> String? {
        if let artworkURL = playlist.artwork?.url(width: 900, height: 900)?.absoluteString,
           !artworkURL.isEmpty {
            return artworkURL
        }

        return playlistArtworkURLsByPlaylistID["\(playlist.id)"]
    }

    private func loadPlaylistArtworkURLsInBackground(for playlists: [Playlist]) {
        let playlistIDs = Set(playlists.map { "\($0.id)" })

        Task { [weak self] in
            guard let self else { return }
            let artworkURLs = await self.musicService.resolvedLibraryPlaylistArtworkURLs(for: playlists)
            guard Set(self.playlists.map({ "\($0.id)" })) == playlistIDs else { return }
            self.playlistArtworkURLsByPlaylistID = artworkURLs
        }
    }

    func seek(to time: TimeInterval) {
        if isUsingApplicationPlayer {
            let boundedTime = max(0, min(time, playbackDuration))
            applicationPlayer.playbackTime = boundedTime
            displayPlaybackTime = boundedTime
            return
        }
        let boundedTime = max(0, min(time, playbackDuration))
        let effectiveTime = boundedTime == 0 ? 0.05 : boundedTime
        let shouldResumePlayback = isPlaying || player.playbackState == .playing

        isManualSeeking = true
        player.currentPlaybackTime = effectiveTime
        displayPlaybackTime = boundedTime

        if shouldResumePlayback {
            startOptimisticPlaybackClock(from: boundedTime)
            player.play()
            isPlaying = true
        } else {
            stopOptimisticPlaybackClock()
        }

        syncCurrentState()
        seekSyncTask?.cancel()
        seekSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self else { return }

            if shouldResumePlayback, self.player.playbackState != .playing {
                self.startOptimisticPlaybackClock(from: self.displayPlaybackTime)
                self.player.play()
                self.isPlaying = true
            }

            if boundedTime == 0, self.player.currentPlaybackTime == 0 {
                self.player.currentPlaybackTime = 0.05
            }

            self.syncCurrentState()
            self.isManualSeeking = false
        }
    }

    // MARK: - 재생/일시정지
    func togglePlayPause() async {
        if isUsingApplicationPlayer {
            if applicationPlayer.state.playbackStatus == .playing {
                applicationPlayer.pause()
            } else {
                try? await applicationPlayer.play()
            }
            syncCurrentState()
            return
        }

        if isPlaying {
            player.pause()
            stopOptimisticPlaybackClock()
            isPlaying = false
        } else {
            startOptimisticPlaybackClock(from: displayPlaybackTime)
            player.play()
            isPlaying = true
        }
    }

    // MARK: - 이전 곡
    func skipToPrevious() async {
        if isUsingApplicationPlayer {
            try? await applicationPlayer.skipToPreviousEntry()
            syncCurrentState()
            return
        }
        guard canSkipToPrevious else { return }
        let newIndex = currentSongIndex - 1
        isGoingForward = false
        presentTrack(at: newIndex, mediaItem: cachedMediaItems[newIndex])
        player.nowPlayingItem = cachedMediaItems[newIndex]
        player.play()
        await synchronizeTrackTransition(to: newIndex)
    }

    // MARK: - 다음 곡
    func skipToNext() async {
        if isUsingApplicationPlayer {
            try? await applicationPlayer.skipToNextEntry()
            syncCurrentState()
            return
        }
        guard canSkipToNext else { return }
        let newIndex = currentSongIndex + 1
        isGoingForward = true
        presentTrack(at: newIndex, mediaItem: cachedMediaItems[newIndex])
        player.nowPlayingItem = cachedMediaItems[newIndex]
        player.play()
        await synchronizeTrackTransition(to: newIndex)
    }

    // MARK: - 현재 상태 동기화
    func syncCurrentState() {
        if isUsingApplicationPlayer,
           let entry = applicationPlayer.queue.currentEntry {
            musicService.playbackContext.sync(title: entry.title, artist: entry.subtitle)
            let song = applicationSong(from: entry)
            currentSong = musicService.playbackContext.currentSong
            pendingTrackPersistentID = nil
            isPlaying = applicationPlayer.state.playbackStatus == .playing
            applicationPlaybackDuration = song?.duration ?? 0
            // pause/state 알림마다 0초를 다시 대입하면 실제 재생 위치가 잠깐
            // 처음으로 튀었다가 폴링 주기에 맞춰 복귀한다. 플레이어의 현재 값을
            // 즉시 반영해 일시정지와 시킹 모두 같은 위치를 유지한다.
            updatePlaybackClock()
            nowPlayingSnapshot = PlayerSongSnapshot(
                title: entry.title,
                artistName: entry.subtitle ?? "Apple Music",
                songStoreID: entry.id,
                artworkURL: entry.artwork?.url(width: 900, height: 900)?.absoluteString
                    ?? song?.artwork?.url(width: 900, height: 900)?.absoluteString,
                artwork: nowPlayingSnapshot?.songStoreID == entry.id ? nowPlayingSnapshot?.artwork : nil
            )
            if let index = queueSongs.firstIndex(where: { "\($0.id)" == entry.id })
                ?? queueSongs.firstIndex(where: {
                $0.title.caseInsensitiveCompare(entry.title) == .orderedSame &&
                ($0.artistName.caseInsensitiveCompare(entry.subtitle ?? "") == .orderedSame || entry.subtitle == nil)
            })
                ?? queueSongs.firstIndex(where: {
                    $0.title.caseInsensitiveCompare(entry.title) == .orderedSame
                }) {
                isGoingForward = index >= currentSongIndex
                currentSongIndex = index
                currentSong = queueSongs[index]
            }
            resolveApplicationSongMetadataIfNeeded(for: entry, song: song)
            loadApplicationArtworkIfNeeded(for: entry.id, urlString: nowPlayingSnapshot?.artworkURL)
            return
        }

        applicationPlaybackDuration = 0

        let playerIsPlaying = player.playbackState == .playing
        if !isManualSeeking || playerIsPlaying {
            isPlaying = playerIsPlaying
        }
        updatePlaybackClock()
        guard let item = player.nowPlayingItem else {
            currentSong = nil
            nowPlayingSnapshot = nil
            return
        }
        nowPlayingSnapshot = PlayerSongSnapshot(
            title: item.title ?? "",
            artistName: item.artist ?? "Apple Music",
            songStoreID: item.playbackStoreID,
            artworkURL: nil,
            artwork: item.artwork?.image(at: CGSize(width: 320, height: 320))
        )
        if let idx = queueIndex(for: item) {
            if pendingTrackPersistentID == item.persistentID {
                pendingTrackPersistentID = nil
            }
            if !isManualSeeking && idx != currentSongIndex {
                isGoingForward = idx > currentSongIndex
                currentSongIndex = idx
            }
            if idx < queueSongs.count {
                currentSong = queueSongs[idx]
                nowPlayingSnapshot = PlayerSongSnapshot(
                    title: item.title ?? currentSong?.title ?? "",
                    artistName: item.artist ?? currentSong?.artistName ?? "Apple Music",
                    songStoreID: item.playbackStoreID,
                    artworkURL: artworkURL(for: currentSong),
                    artwork: item.artwork?.image(at: CGSize(width: 320, height: 320))
                )
            }
        }
    }

    private func presentTrack(at index: Int, mediaItem: MPMediaItem?) {
        currentSongIndex = index
        let song = queueSongs.indices.contains(index) ? queueSongs[index] : nil
        currentSong = song
        pendingTrackPersistentID = mediaItem?.persistentID
        nowPlayingSnapshot = PlayerSongSnapshot(
            title: mediaItem?.title ?? song?.title ?? "",
            artistName: mediaItem?.artist ?? song?.artistName ?? "Apple Music",
            songStoreID: mediaItem?.playbackStoreID ?? song.map { "\($0.id)" } ?? "",
            artworkURL: artworkURL(for: song),
            artwork: mediaItem?.artwork?.image(at: CGSize(width: 320, height: 320))
        )
        displayPlaybackTime = 0
        stopOptimisticPlaybackClock()
    }

    private func applicationSong(from entry: MusicKit.MusicPlayer.Queue.Entry) -> Song? {
        if let contextSong = musicService.playbackContext.currentSong,
           contextSong.title.caseInsensitiveCompare(entry.title) == .orderedSame &&
           (entry.subtitle == nil || contextSong.artistName.caseInsensitiveCompare(entry.subtitle ?? "") == .orderedSame) {
            return contextSong
        }
        if let resolvedSong = resolvedApplicationSongsByEntryID[entry.id] {
            return resolvedSong
        }
        guard let item = entry.item,
              case let .song(song) = item
        else { return nil }
        return song
    }

    private func loadApplicationArtworkIfNeeded(for entryID: String, urlString: String?) {
        guard let urlString, let url = URL(string: urlString),
              resolvingApplicationArtworkIDs.insert(entryID).inserted
        else { return }

        Task { [weak self] in
            let image = await ArtworkImageStore.shared.image(for: url)
            guard let self,
                  self.applicationPlayer.queue.currentEntry?.id == entryID
            else { return }
            self.resolvingApplicationArtworkIDs.remove(entryID)
            guard let snapshot = self.nowPlayingSnapshot,
                  snapshot.songStoreID == entryID
            else { return }
            self.nowPlayingSnapshot = PlayerSongSnapshot(
                title: snapshot.title,
                artistName: snapshot.artistName,
                songStoreID: snapshot.songStoreID,
                artworkURL: snapshot.artworkURL,
                artwork: image
            )
        }
    }

    private func resolveApplicationSongMetadataIfNeeded(
        for entry: MusicKit.MusicPlayer.Queue.Entry,
        song: Song?
    ) {
        guard resolvedApplicationSongsByEntryID[entry.id] == nil,
              !resolvingApplicationEntryIDs.contains(entry.id),
              let item = entry.item,
              case let .song(queueSong) = item,
              (queueSong.artwork == nil || queueSong.duration == nil)
        else { return }

        resolvingApplicationEntryIDs.insert(entry.id)

        Task { [weak self] in
            guard let self else { return }
            let resolvedSong = await self.musicService.resolveCatalogSong(id: queueSong.id)
            self.resolvingApplicationEntryIDs.remove(entry.id)
            guard let resolvedSong,
                  self.applicationPlayer.queue.currentEntry?.id == entry.id
            else { return }
            self.resolvedApplicationSongsByEntryID[entry.id] = resolvedSong
            self.syncCurrentState()
        }
    }

    private func synchronizeTrackTransition(to index: Int) async {
        let targetItem = cachedMediaItems[index]

        for delay: UInt64 in [80_000_000, 180_000_000] {
            try? await Task.sleep(nanoseconds: delay)
            if player.nowPlayingItem?.persistentID == targetItem.persistentID {
                syncCurrentState()
                return
            }
        }

        // 시스템 플레이어가 항목 변경 알림을 놓친 경우에도 실제 재생 큐를 보정한다.
        player.nowPlayingItem = targetItem
        player.play()
        syncCurrentState()
    }

    private func queueIndex(for item: MPMediaItem) -> Int? {
        if let index = cachedMediaItems.firstIndex(where: { $0.persistentID == item.persistentID }) {
            return index
        }

        let storeID = item.playbackStoreID
        if !storeID.isEmpty,
           let index = queueSongs.firstIndex(where: { "\($0.id)" == storeID }) {
            return index
        }

        return queueSongs.firstIndex { song in
            song.title == item.title && song.artistName == item.artist
        }
    }

    // MARK: - 재생 상태 구독
    private func observePlaybackState() {
        player.beginGeneratingPlaybackNotifications()

        let stateObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.syncCurrentState()
            }
        }

        let itemObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncCurrentState()
            }
        }

        notificationObservers = [stateObserver, itemObserver]
        observeApplicationPlayer()
    }

    private func observeApplicationPlayer() {
        applicationStateObserver = applicationPlayer.state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.syncCurrentState() }

        let queueObserver = NotificationCenter.default.addObserver(
            forName: .applicationMusicPlayerQueueDidChange,
            object: applicationPlayer,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bindApplicationQueue()
                self?.syncCurrentState()
            }
        }
        notificationObservers.append(queueObserver)
        bindApplicationQueue()

        applicationPlaybackPoller = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.syncCurrentState() }
    }

    private func bindApplicationQueue() {
        applicationQueueObserver = applicationPlayer.queue.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.syncCurrentState() }
    }

    private func startPlaybackClock() {
        playbackClock = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePlaybackClock()
            }
    }

    private func updatePlaybackClock() {
        if isUsingApplicationPlayer {
            let duration = playbackDuration
            let playbackTime = max(0, applicationPlayer.playbackTime)
            displayPlaybackTime = duration > 0 ? min(playbackTime, duration) : playbackTime
            return
        }

        let rawTime = max(0, player.currentPlaybackTime)
        let duration = playbackDuration
        let boundedRawTime = duration > 0 ? min(rawTime, duration) : rawTime

        if let baseTime = optimisticPlaybackBaseTime,
           let startedAt = optimisticPlaybackStartedAt {
            let syntheticTime = max(0, baseTime + Date().timeIntervalSince(startedAt))
            let boundedSyntheticTime = duration > 0 ? min(syntheticTime, duration) : syntheticTime

            if rawTime > baseTime + 0.2 {
                stopOptimisticPlaybackClock()
                displayPlaybackTime = boundedRawTime
            } else {
                displayPlaybackTime = boundedSyntheticTime
            }
            return
        }

        displayPlaybackTime = boundedRawTime
    }

    private func startOptimisticPlaybackClock(from time: TimeInterval) {
        optimisticPlaybackBaseTime = max(0, time)
        optimisticPlaybackStartedAt = Date()
    }

    private func stopOptimisticPlaybackClock() {
        optimisticPlaybackBaseTime = nil
        optimisticPlaybackStartedAt = nil
    }
}
