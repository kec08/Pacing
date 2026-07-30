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
    @Published private(set) var currentPlaylistName: String? = nil
    @Published private(set) var queueArtworkURLsBySongID: [String: String] = [:]
    @Published private(set) var playlistArtworkURLsByPlaylistID: [String: String] = [:]

    private let player = MPMusicPlayerController.systemMusicPlayer
    private let musicService = AppleMusicRecommendationService.shared
    private let playlistRetryDelays: [UInt64] = [500_000_000, 1_200_000_000, 2_500_000_000]
    private var isManualSeeking: Bool = false
    private var seekSyncTask: Task<Void, Never>?
    private var playbackClock: AnyCancellable?
    private var optimisticPlaybackBaseTime: TimeInterval?
    private var optimisticPlaybackStartedAt: Date?
    private var pendingTrackPersistentID: MPMediaEntityPersistentID?
    // 재생 중인 플레이리스트의 MPMediaItem 캐시
    private var cachedMediaItems: [MPMediaItem] = []
    private var notificationObservers: [NSObjectProtocol] = []

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
                let fetchedPlaylists = try await musicService.fetchLibraryPlaylists(limit: 8)
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
        currentPlaylistName = playlist.name

        // MusicKit에서 트랙 정보 로드
        if let loaded = try? await playlist.with([.tracks]) {
            queueSongs = loaded.tracks?.compactMap { track -> Song? in
                if case .song(let song) = track { return song }
                return nil
            } ?? []
        } else {
            queueSongs = []
        }

        queueArtworkURLsBySongID = await musicService.resolvedArtworkURLs(for: queueSongs)

        // MPMediaQuery로 플레이리스트 찾아서 재생
        let query = MPMediaQuery.playlists()
        let mediaPlaylists = query.collections as? [MPMediaPlaylist] ?? []

        if let match = mediaPlaylists.first(where: { $0.name == playlist.name }) {
            cachedMediaItems = match.items
            let collection = MPMediaItemCollection(items: match.items)
            player.setQueue(with: collection)
            try? await player.prepareToPlay()
            player.play()
            presentTrack(at: 0, mediaItem: match.items.first)
            syncCurrentState()
        } else {
            cachedMediaItems = []
        }
    }

    // MARK: - 인덱스로 곡 직접 이동 (캐시된 아이템 활용)
    func play(at index: Int) async {
        guard index >= 0, index < cachedMediaItems.count else { return }
        isManualSeeking = true
        let targetItem = cachedMediaItems[index]
        presentTrack(at: index, mediaItem: targetItem)
        player.nowPlayingItem = targetItem
        player.play()
        syncCurrentState()
        try? await Task.sleep(nanoseconds: 80_000_000)
        syncCurrentState()
        isManualSeeking = false
    }

    // MARK: - 재생 시간
    var currentPlaybackTime: TimeInterval { displayPlaybackTime }
    var playbackDuration: TimeInterval { player.nowPlayingItem?.playbackDuration ?? 0 }

    var displaySongTitle: String {
        currentSong?.title ?? nowPlayingSnapshot?.title ?? "플레이리스트를 선택하세요"
    }

    var displayArtistName: String {
        currentSong?.artistName ?? nowPlayingSnapshot?.artistName ?? "Apple Music"
    }

    var hasDisplaySong: Bool {
        currentSong != nil || nowPlayingSnapshot != nil
    }

    func currentSongSnapshot() -> PlayerSongSnapshot? {
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
        guard currentSongIndex > 0 else { return }
        let newIndex = currentSongIndex - 1
        isGoingForward = false
        presentTrack(at: newIndex, mediaItem: cachedMediaItems[newIndex])
        player.skipToPreviousItem()
        await synchronizeTrackTransition(to: newIndex)
    }

    // MARK: - 다음 곡
    func skipToNext() async {
        guard currentSongIndex + 1 < cachedMediaItems.count else { return }
        let newIndex = currentSongIndex + 1
        isGoingForward = true
        presentTrack(at: newIndex, mediaItem: cachedMediaItems[newIndex])
        player.skipToNextItem()
        await synchronizeTrackTransition(to: newIndex)
    }

    // MARK: - 현재 상태 동기화
    func syncCurrentState() {
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
        guard queueSongs.indices.contains(index) else { return }

        currentSongIndex = index
        currentSong = queueSongs[index]
        pendingTrackPersistentID = mediaItem?.persistentID
        nowPlayingSnapshot = PlayerSongSnapshot(
            title: mediaItem?.title ?? currentSong?.title ?? "",
            artistName: mediaItem?.artist ?? currentSong?.artistName ?? "Apple Music",
            songStoreID: mediaItem?.playbackStoreID ?? "\(queueSongs[index].id)",
            artworkURL: artworkURL(for: queueSongs[index]),
            artwork: mediaItem?.artwork?.image(at: CGSize(width: 320, height: 320))
        )
        displayPlaybackTime = 0
        stopOptimisticPlaybackClock()
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
                let playerIsPlaying = self.player.playbackState == .playing
                if !self.isManualSeeking || playerIsPlaying {
                    self.isPlaying = playerIsPlaying
                }
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
    }

    private func startPlaybackClock() {
        playbackClock = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePlaybackClock()
            }
    }

    private func updatePlaybackClock() {
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
