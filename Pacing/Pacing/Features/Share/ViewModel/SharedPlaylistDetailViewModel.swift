import Foundation
import Combine
import FirebaseAuth
import MusicKit
import MediaPlayer
import UIKit

@MainActor
final class SharedPlaylistDetailViewModel: ObservableObject {
    private struct DetailCacheEntry {
        let summary: SharedPlaylistSummary
        let tracks: [SharedPlaylistTrack]
        let appSaveState: SharedPlaylistSaveState
        let didSaveToAppleMusic: Bool
        let canSaveToAppleMusic: Bool
        let cachedAt: Date
    }

    private static var detailCache: [String: DetailCacheEntry] = [:]
    private static let cacheLifetime: TimeInterval = 10 * 60

    enum Source {
        case shared(SharedPlaylistSummary)
        case recommendation(Playlist)
        case album(Album)
        case station(Station)
    }

    @Published private(set) var summary: SharedPlaylistSummary
    @Published var tracks: [SharedPlaylistTrack]
    @Published var isLoading: Bool = false
    @Published var isPlaying: Bool = false
    @Published var playingTrackID: String?
    @Published private(set) var nowPlayingTitle: String = ""
    @Published private(set) var nowPlayingArtist: String = ""
    @Published private(set) var nowPlayingArtwork: UIImage?
    @Published var appSaveState: SharedPlaylistSaveState = .idle
    @Published var didSaveToAppleMusic: Bool = false
    @Published var canSaveToAppleMusic: Bool = false
    @Published var errorMessage: String?

    private let source: Source
    private let firestoreService = FirestoreService.shared
    private let musicService = AppleMusicRecommendationService.shared
    private let systemPlayer = MPMusicPlayerController.systemMusicPlayer
    private let applicationPlayer = ApplicationMusicPlayer.shared
    private var recommendationPlaylist: Playlist?
    private var recentAlbum: Album?
    private var recommendedStation: Station?
    private var notificationObservers: [NSObjectProtocol] = []
    private var applicationQueueObserver: AnyCancellable?
    private var applicationStateObserver: AnyCancellable?
    private var applicationPlaybackPoller: AnyCancellable?
    private var isStartingPlayback = false
    private var pendingPlaybackTrackID: String?

    init(sharedPlaylist: SharedPlaylistSummary) {
        self.source = .shared(sharedPlaylist)
        self.summary = sharedPlaylist
        self.tracks = sharedPlaylist.tracks
        observePlayback()
    }

    init(recommendedPlaylist: Playlist) {
        let summary = SharedPlaylistSummary(
            id: "recommended_\(recommendedPlaylist.id)",
            ownerUID: "apple_music",
            ownerNickname: "Apple Music",
            title: recommendedPlaylist.name,
            subtitle: recommendedPlaylist.curatorName ?? recommendedPlaylist.shortDescription ?? "추천 플레이리스트",
            artworkURL: recommendedPlaylist.artwork?.url(width: 800, height: 800)?.absoluteString,
            artworkData: nil,
            sourcePlaylistID: "\(recommendedPlaylist.id)",
            sourcePlaylistURL: recommendedPlaylist.url?.absoluteString,
            trackCount: 0,
            updatedAt: recommendedPlaylist.lastModifiedDate,
            tracks: []
        )
        self.source = .recommendation(recommendedPlaylist)
        self.summary = summary
        self.tracks = []
        self.recommendationPlaylist = recommendedPlaylist
        observePlayback()
    }

    init(recentAlbum: Album) {
        let summary = SharedPlaylistSummary(
            id: "recent_album_\(recentAlbum.id)",
            ownerUID: "apple_music",
            ownerNickname: recentAlbum.artistName,
            title: recentAlbum.title,
            subtitle: recentAlbum.artistName,
            artworkURL: recentAlbum.artwork?.url(width: 800, height: 800)?.absoluteString,
            artworkData: nil,
            sourcePlaylistID: "\(recentAlbum.id)",
            sourcePlaylistURL: recentAlbum.url?.absoluteString,
            trackCount: recentAlbum.trackCount,
            updatedAt: recentAlbum.lastPlayedDate ?? recentAlbum.releaseDate,
            tracks: []
        )
        self.source = .album(recentAlbum)
        self.summary = summary
        self.tracks = []
        self.recentAlbum = recentAlbum
        observePlayback()
    }

    init(recommendedStation: Station) {
        let summary = SharedPlaylistSummary(
            id: "recommended_station_\(recommendedStation.id)",
            ownerUID: "apple_music_station",
            ownerNickname: "Apple Music Radio",
            title: recommendedStation.name,
            subtitle: "Apple Music 스테이션",
            artworkURL: recommendedStation.artwork?.url(width: 800, height: 800)?.absoluteString,
            artworkData: nil,
            sourcePlaylistID: "\(recommendedStation.id)",
            sourcePlaylistURL: recommendedStation.url?.absoluteString,
            trackCount: 0,
            updatedAt: nil,
            tracks: []
        )
        self.source = .station(recommendedStation)
        self.summary = summary
        self.tracks = []
        self.recommendedStation = recommendedStation
        observePlayback()
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        systemPlayer.endGeneratingPlaybackNotifications()
    }

    func load() async {
        guard !isLoading else { return }

        if applyCachedDetailIfAvailable() {
            return
        }

        isLoading = true
        defer {
            isLoading = false
            cacheCurrentDetail()
        }

        do {
            switch source {
            case .shared:
                // 전달받은 스냅샷을 먼저 표시한다. 상세 진입 시 제목 검색을 하면
                // 유사 제목의 다른 곡으로 바뀌고 목록이 늦게 나타날 수 있다.
                tracks = summary.tracks
                // 과거 공유 문서에는 곡 커버가 비어 있을 수 있다. 대표 커버는
                // 소유자 설정값을 유지하고, 수록곡 커버만 현재 기기에서 보강한다.
                let enrichedTracks = await musicService.prepareSharedTracksForPlayback(summary.tracks)
                tracks = enrichedTracks
                summary = SharedPlaylistSummary(
                    id: summary.id,
                    ownerUID: summary.ownerUID,
                    ownerNickname: summary.ownerNickname,
                    title: summary.title,
                    subtitle: summary.subtitle,
                    artworkURL: summary.artworkURL,
                    artworkData: summary.artworkData,
                    sourcePlaylistID: summary.sourcePlaylistID,
                    sourcePlaylistURL: summary.sourcePlaylistURL,
                    trackCount: summary.trackCount,
                    updatedAt: summary.updatedAt,
                    tracks: enrichedTracks
                )

                if let uid = Auth.auth().currentUser?.uid {
                    let isSaved = try await firestoreService.isSavedSharedPlaylist(uid: uid, playlistID: summary.id)
                    appSaveState = isSaved ? .saved : .idle
                }
                canSaveToAppleMusic = (try? await musicService.currentSubscription())?.canPlayCatalogContent ?? false
            case .recommendation(let playlist):
                let loadedTracks = try await musicService.loadTracks(for: playlist)
                tracks = loadedTracks
                summary = SharedPlaylistSummary(
                    id: summary.id,
                    ownerUID: summary.ownerUID,
                    ownerNickname: summary.ownerNickname,
                    title: summary.title,
                    subtitle: summary.subtitle,
                    artworkURL: summary.artworkURL,
                    artworkData: summary.artworkData,
                    sourcePlaylistID: summary.sourcePlaylistID,
                    sourcePlaylistURL: summary.sourcePlaylistURL,
                    trackCount: loadedTracks.count,
                    updatedAt: summary.updatedAt,
                    tracks: loadedTracks
                )

                let subscription = try await musicService.currentSubscription()
                canSaveToAppleMusic = subscription.canPlayCatalogContent
                didSaveToAppleMusic = playlist.libraryAddedDate != nil
                if let uid = Auth.auth().currentUser?.uid {
                    let isSaved = try await firestoreService.isSavedSharedPlaylist(uid: uid, playlistID: summary.id)
                    appSaveState = isSaved ? .saved : .idle
                }
            case .album(let album):
                let loadedTracks = try await musicService.loadTracks(for: album)
                tracks = loadedTracks
                summary = SharedPlaylistSummary(
                    id: summary.id,
                    ownerUID: summary.ownerUID,
                    ownerNickname: summary.ownerNickname,
                    title: summary.title,
                    subtitle: summary.subtitle,
                    artworkURL: summary.artworkURL,
                    artworkData: summary.artworkData,
                    sourcePlaylistID: summary.sourcePlaylistID,
                    sourcePlaylistURL: summary.sourcePlaylistURL,
                    trackCount: loadedTracks.count,
                    updatedAt: summary.updatedAt,
                    tracks: loadedTracks
                )

                let subscription = try await musicService.currentSubscription()
                canSaveToAppleMusic = subscription.canPlayCatalogContent
                didSaveToAppleMusic = album.libraryAddedDate != nil
                appSaveState = didSaveToAppleMusic ? .saved : .idle
            case .station:
                tracks = []
                canSaveToAppleMusic = false
                didSaveToAppleMusic = false
                appSaveState = .idle
            }
        } catch {
            errorMessage = "플레이리스트 정보를 불러오지 못했어요."
        }
    }

    private var detailCacheKey: String {
        let version = summary.updatedAt?.timeIntervalSinceReferenceDate ?? 0
        let userID = Auth.auth().currentUser?.uid ?? "anonymous"
        return "\(userID)_\(summary.id)_\(version)"
    }

    private func applyCachedDetailIfAvailable() -> Bool {
        guard let cachedDetail = Self.detailCache[detailCacheKey],
              Date().timeIntervalSince(cachedDetail.cachedAt) < Self.cacheLifetime
        else {
            return false
        }

        summary = cachedDetail.summary
        tracks = cachedDetail.tracks
        appSaveState = cachedDetail.appSaveState
        didSaveToAppleMusic = cachedDetail.didSaveToAppleMusic
        canSaveToAppleMusic = cachedDetail.canSaveToAppleMusic
        return true
    }

    private func cacheCurrentDetail() {
        guard !tracks.isEmpty else { return }

        Self.detailCache[detailCacheKey] = DetailCacheEntry(
            summary: summary,
            tracks: tracks,
            appSaveState: appSaveState,
            didSaveToAppleMusic: didSaveToAppleMusic,
            canSaveToAppleMusic: canSaveToAppleMusic,
            cachedAt: Date()
        )
    }

    func playAll() async {
        let firstTrackID = tracks.first?.id
        pendingPlaybackTrackID = firstTrackID
        playingTrackID = firstTrackID
        isStartingPlayback = true
        isPlaying = true

        do {
            switch source {
            case .shared:
                try await musicService.play(sharedTracks: tracks)
            case .recommendation(let playlist):
                try await musicService.play(playlist: playlist)
            case .album(let album):
                try await musicService.play(album: album)
            case .station(let station):
                try await musicService.play(station: station)
                playingTrackID = nil
            }
            // 큐 교체 직후에는 이전 플레이어 상태 알림이 먼저 도착할 수 있다.
            // 재생이 실제로 시작된 뒤 첫 곡 표시를 다시 확정한다.
            if !isStationSource {
                playingTrackID = firstTrackID
            }
            isStartingPlayback = false
        } catch {
            isStartingPlayback = false
            isPlaying = false
            playingTrackID = nil
            pendingPlaybackTrackID = nil
            errorMessage = "재생을 시작하지 못했어요."
        }
    }

    func play(track: SharedPlaylistTrack) async {
        pendingPlaybackTrackID = track.id
        playingTrackID = track.id
        isStartingPlayback = true

        do {
            try await musicService.play(sharedTracks: tracks, startingAt: track.id)
            playingTrackID = track.id
            isStartingPlayback = false
        } catch {
            isStartingPlayback = false
            playingTrackID = nil
            pendingPlaybackTrackID = nil
            errorMessage = "곡 재생을 시작하지 못했어요."
        }
    }

    func isCurrentTrack(_ track: SharedPlaylistTrack) -> Bool {
        guard isPlaying else { return false }
        if let contextSong = musicService.playbackContext.currentSong {
            return track.title.caseInsensitiveCompare(contextSong.title) == .orderedSame &&
                track.artistName.caseInsensitiveCompare(contextSong.artistName) == .orderedSame
        }
        if !nowPlayingTitle.isEmpty {
            return track.title.caseInsensitiveCompare(nowPlayingTitle) == .orderedSame &&
                (nowPlayingArtist.isEmpty || track.artistName.caseInsensitiveCompare(nowPlayingArtist) == .orderedSame)
        }
        return playingTrackID == track.id
    }

    func savePrimaryPlaylist() async {
        guard !isSaveButtonDisabled else { return }
        errorMessage = nil

        switch source {
        case .shared:
            await savePlaylist()
        case .recommendation:
            await saveRecommendationPlaylist()
        case .album:
            await saveAlbum()
        case .station:
            errorMessage = "스테이션은 따로 저장할 수 없어요."
        }
    }

    func savePlaylist() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard appSaveState != .saving && appSaveState != .saved else { return }
        guard canSaveToAppleMusic else {
            errorMessage = "Apple Music 보관함에 저장할 수 없는 상태예요."
            return
        }

        appSaveState = .saving

        do {
            let libraryPlaylistID: String
            if let pendingLibraryPlaylistID = pendingLibraryPlaylistID(for: uid) {
                libraryPlaylistID = pendingLibraryPlaylistID
            } else {
                libraryPlaylistID = try await musicService.createLibraryPlaylist(
                    name: summary.title,
                    authorDisplayName: summary.ownerNickname,
                    sharedTracks: tracks
                )
                // Apple Music 생성 뒤 Firestore 기록만 실패한 경우 재시도해도
                // 동일 플레이리스트가 중복 생성되지 않도록 임시 식별자를 보관한다.
                UserDefaults.standard.set(libraryPlaylistID, forKey: pendingLibraryPlaylistIDKey(for: uid))
            }
            try await firestoreService.saveSharedPlaylistToLibrary(
                uid: uid,
                summary: summary,
                appleMusicLibraryPlaylistID: libraryPlaylistID
            )
            UserDefaults.standard.removeObject(forKey: pendingLibraryPlaylistIDKey(for: uid))
            didSaveToAppleMusic = true
            appSaveState = .saved
        } catch {
            appSaveState = .idle
            errorMessage = "Apple Music 플레이리스트를 저장하지 못했어요."
        }
    }

    private func pendingLibraryPlaylistID(for uid: String) -> String? {
        let value = UserDefaults.standard.string(forKey: pendingLibraryPlaylistIDKey(for: uid))
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return value
    }

    private func pendingLibraryPlaylistIDKey(for uid: String) -> String {
        "pendingAppleMusicPlaylistID_\(uid)_\(summary.id)"
    }

    func saveToAppleMusic() async {
        guard canSaveToAppleMusic, !didSaveToAppleMusic else { return }
        switch source {
        case .recommendation(let playlist):
            do {
                try await musicService.addToLibrary(playlist: playlist)
                didSaveToAppleMusic = true
            } catch {
                errorMessage = "Apple Music에 저장하지 못했어요."
            }
        case .album(let album):
            do {
                try await musicService.addToLibrary(album: album)
                didSaveToAppleMusic = true
            } catch {
                errorMessage = "Apple Music에 저장하지 못했어요."
            }
        case .shared:
            return
        case .station:
            return
        }
    }

    private func saveAlbum() async {
        guard appSaveState != .saving else { return }
        guard canSaveToAppleMusic else {
            errorMessage = "앨범을 저장할 수 없는 상태예요."
            return
        }

        appSaveState = .saving

        if !didSaveToAppleMusic {
            await saveToAppleMusic()
            guard errorMessage == nil else {
                appSaveState = .idle
                return
            }
        }

        appSaveState = .saved
    }

    private func saveRecommendationPlaylist() async {
        guard appSaveState != .saving else { return }
        guard canSaveToAppleMusic else {
            errorMessage = "Apple Music 보관함에 저장할 수 없는 상태예요."
            return
        }

        appSaveState = .saving

        if !didSaveToAppleMusic {
            await saveToAppleMusic()
            guard errorMessage == nil else {
                appSaveState = .idle
                return
            }
        }

        if let uid = Auth.auth().currentUser?.uid {
            do {
                try await firestoreService.saveSharedPlaylistToLibrary(uid: uid, summary: summary)
            } catch {
                appSaveState = .idle
                errorMessage = "플레이리스트를 저장하지 못했어요."
                return
            }
        }

        appSaveState = .saved
    }

    var primarySaveTitle: String {
        if appSaveState == .saved {
            return "저장됨"
        }

        switch source {
        case .album:
            return "앨범 저장"
        case .station:
            return "저장 불가"
        case .shared, .recommendation:
            return "플레이리스트 저장"
        }
    }

    var isSaveButtonDisabled: Bool {
        if case .station = source {
            return true
        }
        return appSaveState == .saving || appSaveState == .saved
    }

    var isSaving: Bool {
        appSaveState == .saving
    }

    var isPlaybackActive: Bool {
        isPlaying || playingTrackID != nil
    }

    var hasMiniPlayerContent: Bool {
        isAlbumSource && !nowPlayingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var ownerDescription: String {
        switch source {
        case .station:
            return "Apple Music Radio"
        default:
            return summary.ownerNickname
        }
    }

    var isAlbumSource: Bool {
        if case .album = source {
            return true
        }
        return false
    }

    var isStationSource: Bool {
        if case .station = source {
            return true
        }
        return false
    }

    var updatedDescription: String {
        guard let updatedAt = summary.updatedAt else { return "업데이트 정보 없음" }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }

    private func observePlayback() {
        systemPlayer.beginGeneratingPlaybackNotifications()

        let stateObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: systemPlayer,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncPlaybackState()
            }
        }

        let itemObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: systemPlayer,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncCurrentTrack()
            }
        }

        notificationObservers = [stateObserver, itemObserver]
        observeApplicationPlayer()
        syncPlaybackState()
        syncCurrentTrack()
    }

    private func observeApplicationPlayer() {
        applicationStateObserver = applicationPlayer.state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.syncCurrentTrack()
            }

        let queueObserver = NotificationCenter.default.addObserver(
            forName: .applicationMusicPlayerQueueDidChange,
            object: applicationPlayer,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bindApplicationQueue()
                self?.syncCurrentTrack()
            }
        }
        notificationObservers.append(queueObserver)
        bindApplicationQueue()

        applicationPlaybackPoller = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard self?.applicationPlayer.state.playbackStatus != .stopped else { return }
                self?.syncCurrentTrack()
            }
    }

    private func bindApplicationQueue() {
        applicationQueueObserver = applicationPlayer.queue.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.syncCurrentTrack()
            }
    }

    private func syncPlaybackState() {
        if applicationPlayer.queue.currentEntry != nil,
           applicationPlayer.state.playbackStatus != .stopped {
            isPlaying = applicationPlayer.state.playbackStatus == .playing
            return
        }

        isPlaying = systemPlayer.playbackState == .playing
        if !isPlaying && systemPlayer.nowPlayingItem == nil {
            playingTrackID = nil
        }
    }

    private func syncCurrentTrack() {
        syncPlaybackState()

        if let entry = applicationPlayer.queue.currentEntry,
           applicationPlayer.state.playbackStatus != .stopped {
            nowPlayingTitle = entry.title
            nowPlayingArtist = entry.subtitle ?? summary.ownerNickname
            nowPlayingArtwork = nil

            let currentTitle = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let currentArtist = (entry.subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let matchedTrack = tracks.first(where: {
                $0.title.caseInsensitiveCompare(currentTitle) == .orderedSame &&
                ($0.artistName.caseInsensitiveCompare(currentArtist) == .orderedSame || currentArtist.isEmpty)
            }) {
                playingTrackID = matchedTrack.id
                pendingPlaybackTrackID = nil
            } else {
                // 이전에 선택한 곡이 남아 있으면 다음 곡으로 넘어가도 핑크 표시가 고정된다.
                playingTrackID = nil
                pendingPlaybackTrackID = nil
            }
            return
        }

        guard let item = systemPlayer.nowPlayingItem else {
            nowPlayingTitle = ""
            nowPlayingArtist = ""
            nowPlayingArtwork = nil
            if !isPlaying && !isStartingPlayback {
                playingTrackID = nil
                pendingPlaybackTrackID = nil
            }
            return
        }

        nowPlayingTitle = item.title ?? ""
        nowPlayingArtist = item.artist ?? summary.ownerNickname
        nowPlayingArtwork = item.artwork?.image(at: CGSize(width: 220, height: 220))

        let currentStoreID = item.playbackStoreID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let matchedTrack = tracks.first(where: { $0.songStoreID == currentStoreID && !currentStoreID.isEmpty }) {
            playingTrackID = matchedTrack.id
            pendingPlaybackTrackID = nil
            return
        }

        let currentTitle = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let currentArtist = item.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let matchedTrack = tracks.first(where: {
            $0.title.caseInsensitiveCompare(currentTitle) == .orderedSame &&
            $0.artistName.caseInsensitiveCompare(currentArtist) == .orderedSame
        }) {
            playingTrackID = matchedTrack.id
            pendingPlaybackTrackID = nil
            return
        }

        playingTrackID = nil
        pendingPlaybackTrackID = nil
    }

    func togglePlayPause() {
        if isPlaying {
            systemPlayer.pause()
        } else {
            systemPlayer.play()
        }
        syncPlaybackState()
    }

    func skipToNext() {
        if applicationPlayer.queue.currentEntry != nil,
           applicationPlayer.state.playbackStatus != .stopped {
            Task { [weak self] in
                guard let self else { return }
                try? await self.applicationPlayer.skipToNextEntry()
                self.syncCurrentTrack()
            }
        } else {
            systemPlayer.skipToNextItem()
            syncCurrentTrack()
        }
    }
}
