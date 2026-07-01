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

    private let player = MPMusicPlayerController.systemMusicPlayer
    private var isManualSeeking: Bool = false
    // 재생 중인 플레이리스트의 MPMediaItem 캐시
    private var cachedMediaItems: [MPMediaItem] = []
    private var notificationObservers: [NSObjectProtocol] = []

    init() {
        observePlaybackState()
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        player.endGeneratingPlaybackNotifications()
    }

    // MARK: - 권한 요청
    func requestAuthorization() async {
        authStatus = await MusicAuthorization.request()
        if authStatus == .authorized {
            await fetchPlaylists()
            syncCurrentState()
        }
    }

    // MARK: - 플레이리스트 fetch
    func fetchPlaylists() async {
        guard authStatus == .authorized else { return }
        isLoading = true
        do {
            let request = MusicLibraryRequest<Playlist>()
            let response = try await request.response()
            playlists = Array(response.items)
        } catch {
            playlists = []
        }
        isLoading = false
    }

    // MARK: - 플레이리스트 재생
    func play(playlist: Playlist) async {
        // MusicKit에서 트랙 정보 로드
        if let loaded = try? await playlist.with([.tracks]) {
            queueSongs = loaded.tracks?.compactMap { track -> Song? in
                if case .song(let song) = track { return song }
                return nil
            } ?? []
        }

        // MPMediaQuery로 플레이리스트 찾아서 재생
        let query = MPMediaQuery.playlists()
        let mediaPlaylists = query.collections as? [MPMediaPlaylist] ?? []

        if let match = mediaPlaylists.first(where: { $0.name == playlist.name }) {
            cachedMediaItems = match.items
            let collection = MPMediaItemCollection(items: match.items)
            player.setQueue(with: collection)
            try? await player.prepareToPlay()
            player.play()
            currentSongIndex = 0
            syncCurrentState()
        }
    }

    // MARK: - 인덱스로 곡 직접 이동 (캐시된 아이템 활용)
    func play(at index: Int) async {
        guard index >= 0, index < cachedMediaItems.count else { return }
        isManualSeeking = true
        // UI 애니메이션이 완료된 후 재생 시작
        try? await Task.sleep(nanoseconds: 150_000_000)
        let targetItem = cachedMediaItems[index]
        player.nowPlayingItem = targetItem
        player.play()
        syncCurrentState()
        isManualSeeking = false
    }

    // MARK: - 재생 시간
    var currentPlaybackTime: TimeInterval { player.currentPlaybackTime }
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
        if let item = player.nowPlayingItem, !item.playbackStoreID.isEmpty {
            return PlayerSongSnapshot(
                title: item.title ?? currentSong?.title ?? "",
                artistName: item.artist ?? currentSong?.artistName ?? "Apple Music",
                songStoreID: item.playbackStoreID,
                artworkURL: currentSong?.artwork?.url(width: 320, height: 320)?.absoluteString,
                artwork: item.artwork?.image(at: CGSize(width: 320, height: 320))
            )
        }
        if let currentSong {
            return PlayerSongSnapshot(
                title: currentSong.title,
                artistName: currentSong.artistName,
                songStoreID: "\(currentSong.id)",
                artworkURL: currentSong.artwork?.url(width: 320, height: 320)?.absoluteString,
                artwork: nil
            )
        }
        syncCurrentState()
        return nowPlayingSnapshot
    }

    func seek(to time: TimeInterval) {
        player.currentPlaybackTime = max(0, min(time, playbackDuration))
    }

    // MARK: - 재생/일시정지
    func togglePlayPause() async {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    // MARK: - 이전 곡
    func skipToPrevious() async {
        let newIndex = max(0, currentSongIndex - 1)
        isGoingForward = false
        currentSongIndex = newIndex
        await play(at: newIndex)
    }

    // MARK: - 다음 곡
    func skipToNext() async {
        let newIndex = min(cachedMediaItems.count - 1, currentSongIndex + 1)
        isGoingForward = true
        currentSongIndex = newIndex
        await play(at: newIndex)
    }

    // MARK: - 현재 상태 동기화
    func syncCurrentState() {
        isPlaying = player.playbackState == .playing
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
        if let idx = cachedMediaItems.firstIndex(where: { $0.persistentID == item.persistentID }) {
            if !isManualSeeking && idx != currentSongIndex {
                isGoingForward = idx > currentSongIndex
                currentSongIndex = idx
            }
            if idx < queueSongs.count {
                currentSong = queueSongs[idx]
            }
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
                self?.isPlaying = self?.player.playbackState == .playing
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
}
