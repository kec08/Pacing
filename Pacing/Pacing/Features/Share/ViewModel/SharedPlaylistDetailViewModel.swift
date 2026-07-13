import Foundation
import Combine
import FirebaseAuth
import MusicKit
import MediaPlayer
import UIKit

@MainActor
final class SharedPlaylistDetailViewModel: ObservableObject {
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
    private var recommendationPlaylist: Playlist?
    private var recentAlbum: Album?
    private var recommendedStation: Station?
    private var notificationObservers: [NSObjectProtocol] = []

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
        isLoading = true
        defer { isLoading = false }

        do {
            switch source {
            case .shared:
                if let uid = Auth.auth().currentUser?.uid {
                    let isSaved = try await firestoreService.isSavedSharedPlaylist(uid: uid, playlistID: summary.id)
                    appSaveState = isSaved ? .saved : .idle
                }
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

    func playAll() async {
        if let firstTrack = tracks.first {
            playingTrackID = firstTrack.id
        }
        isPlaying = true

        do {
            switch source {
            case .shared:
                try await musicService.playTracks(with: tracks.compactMap(\.songStoreID))
            case .recommendation(let playlist):
                try await musicService.play(playlist: playlist)
            case .album(let album):
                try await musicService.play(album: album)
            case .station(let station):
                try await musicService.play(station: station)
                playingTrackID = nil
            }
        } catch {
            isPlaying = false
            playingTrackID = nil
            errorMessage = "재생을 시작하지 못했어요."
        }
    }

    func play(track: SharedPlaylistTrack) async {
        guard let songStoreID = track.songStoreID, !songStoreID.isEmpty else {
            errorMessage = "이 곡은 바로 재생할 수 없어요."
            return
        }

        playingTrackID = track.id

        do {
            try await musicService.playTracks(with: [songStoreID])
        } catch {
            playingTrackID = nil
            errorMessage = "곡 재생을 시작하지 못했어요."
        }
    }

    func savePrimaryPlaylist() async {
        guard !isSaveButtonDisabled else { return }

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

        appSaveState = .saving

        do {
            try await firestoreService.saveSharedPlaylistToLibrary(uid: uid, summary: summary)
            appSaveState = .saved
        } catch {
            appSaveState = .idle
            errorMessage = "플레이리스트를 저장하지 못했어요."
        }
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
        guard canSaveToAppleMusic || Auth.auth().currentUser?.uid != nil else {
            errorMessage = "플레이리스트를 저장할 수 없는 상태예요."
            return
        }

        appSaveState = .saving

        if canSaveToAppleMusic, !didSaveToAppleMusic {
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
        syncPlaybackState()
        syncCurrentTrack()
    }

    private func syncPlaybackState() {
        isPlaying = systemPlayer.playbackState == .playing
        if !isPlaying && systemPlayer.nowPlayingItem == nil {
            playingTrackID = nil
        }
    }

    private func syncCurrentTrack() {
        syncPlaybackState()

        guard let item = systemPlayer.nowPlayingItem else {
            nowPlayingTitle = ""
            nowPlayingArtist = ""
            nowPlayingArtwork = nil
            if !isPlaying {
                playingTrackID = nil
            }
            return
        }

        nowPlayingTitle = item.title ?? ""
        nowPlayingArtist = item.artist ?? summary.ownerNickname
        nowPlayingArtwork = item.artwork?.image(at: CGSize(width: 220, height: 220))

        let currentStoreID = item.playbackStoreID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let matchedTrack = tracks.first(where: { $0.songStoreID == currentStoreID && !currentStoreID.isEmpty }) {
            playingTrackID = matchedTrack.id
            return
        }

        let currentTitle = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let currentArtist = item.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let matchedTrack = tracks.first(where: {
            $0.title.caseInsensitiveCompare(currentTitle) == .orderedSame &&
            $0.artistName.caseInsensitiveCompare(currentArtist) == .orderedSame
        }) {
            playingTrackID = matchedTrack.id
            return
        }

        if !isPlaying {
            playingTrackID = nil
        }
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
        systemPlayer.skipToNextItem()
        syncCurrentTrack()
    }
}
