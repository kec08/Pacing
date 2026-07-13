import Foundation
import MusicKit

struct ShareRecommendationBundle {
    let recentlyPlayedAlbums: [Album]
    let playlists: [Playlist]
    let genreAlbumRows: [GenreAlbumRow]
    let moodPlaylists: [MoodPlaylistShelfItem]
}

struct GenreAlbumShelfItem: Identifiable {
    let genreTitle: String
    let album: Album

    var id: String {
        "\(genreTitle)_\(album.id)"
    }
}

struct GenreAlbumRow: Identifiable {
    let genreTitle: String
    let albums: [GenreAlbumShelfItem]

    var id: String { genreTitle }
}

struct MoodPlaylistShelfItem: Identifiable {
    let moodTitle: String
    let playlist: Playlist

    var id: String {
        "\(moodTitle)_\(playlist.id)"
    }
}

enum AppleMusicRecommendationError: LocalizedError {
    case notAuthorized
    case subscriptionUnavailable
    case noPlayableTracks

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Apple Music 권한이 필요해요."
        case .subscriptionUnavailable:
            return "Apple Music 구독 상태를 확인해주세요."
        case .noPlayableTracks:
            return "재생할 수 있는 곡을 찾지 못했어요."
        }
    }
}

@MainActor
final class AppleMusicRecommendationService {
    static let shared = AppleMusicRecommendationService()

    private let player = ApplicationMusicPlayer.shared

    private init() {}

    func requestAuthorizationIfNeeded() async -> MusicAuthorization.Status {
        let current = MusicAuthorization.currentStatus
        guard current != .authorized else { return current }
        return await MusicAuthorization.request()
    }

    func currentSubscription() async throws -> MusicSubscription {
        try await MusicSubscription.current
    }

    func fetchLibraryPlaylists(limit: Int = 6) async throws -> [Playlist] {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = limit
        let response = try await request.response()
        return Array(response.items.prefix(limit))
    }

    func syncCurrentUserPlaylists(uid: String, nickname: String, limit: Int = 6) async throws {
        let playlists = try await fetchLibraryPlaylists(limit: limit)

        for playlist in playlists {
            let loadedPlaylist = try await playlist.with([.tracks], preferredSource: .library)
            let summary = SharedPlaylistSummary(
                id: Self.makeSharedPlaylistDocumentID(ownerUID: uid, sourcePlaylistID: "\(playlist.id)"),
                ownerUID: uid,
                ownerNickname: nickname,
                title: loadedPlaylist.name,
                subtitle: loadedPlaylist.curatorName ?? loadedPlaylist.shortDescription ?? "내 플레이리스트",
                artworkURL: loadedPlaylist.artwork?.url(width: 800, height: 800)?.absoluteString,
                sourcePlaylistID: "\(loadedPlaylist.id)",
                sourcePlaylistURL: loadedPlaylist.url?.absoluteString,
                trackCount: loadedPlaylist.tracks?.count ?? 0,
                updatedAt: Date(),
                tracks: Self.makeSharedTracks(from: loadedPlaylist)
            )
            try await FirestoreService.shared.saveSharedPlaylist(summary)
        }
    }

    func fetchRecommendations(limit: Int = 8) async throws -> ShareRecommendationBundle {
        let authStatus = MusicAuthorization.currentStatus
        guard authStatus == .authorized else {
            throw AppleMusicRecommendationError.notAuthorized
        }

        let subscription = try await currentSubscription()
        guard subscription.canPlayCatalogContent else {
            throw AppleMusicRecommendationError.subscriptionUnavailable
        }

        let recentlyPlayedAlbums: [Album]
        do {
            recentlyPlayedAlbums = try await fetchRecentlyPlayedAlbums(limit: limit)
        } catch {
            // Keep recommendations available even if recent-played lookup fails.
            recentlyPlayedAlbums = []
        }
        var playlists: [Playlist] = []
        let genreAlbumRows = try await fetchGenreAlbumRows()
        let moodPlaylists = try await fetchMoodPlaylists()

        do {
            var request = MusicPersonalRecommendationsRequest()
            request.limit = limit
            let response = try await request.response()

            playlists = response.recommendations
                .flatMap { Array($0.playlists) }
                .uniquedByID()
                .prefix(limit)
                .map { $0 }

        } catch {
            playlists = []
        }

        if playlists.isEmpty {
            var chartsRequest = MusicCatalogChartsRequest(types: [Playlist.self])
            chartsRequest.limit = limit
            let charts = try await chartsRequest.response()
            playlists = charts.playlistCharts
                .flatMap { Array($0.items) }
                .uniquedByID()
                .prefix(limit)
                .map { $0 }
        }

        return ShareRecommendationBundle(
            recentlyPlayedAlbums: recentlyPlayedAlbums,
            playlists: playlists,
            genreAlbumRows: genreAlbumRows,
            moodPlaylists: moodPlaylists
        )
    }

    func fetchGenreAlbumRows() async throws -> [GenreAlbumRow] {
        let genreQueries: [(label: String, term: String)] = [
            ("R&B", "R&B"),
            ("인디", "Indie"),
            ("힙합", "Hip-Hop"),
            ("K-Pop", "K-Pop")
        ]

        var rows: [GenreAlbumRow] = []

        for query in genreQueries {
            var request = MusicCatalogSearchRequest(term: query.term, types: [Album.self])
            request.limit = 5
            let response = try await request.response()

            let albums = response.albums.prefix(6).map {
                GenreAlbumShelfItem(genreTitle: query.label, album: $0)
            }

            if !albums.isEmpty {
                rows.append(GenreAlbumRow(genreTitle: query.label, albums: Array(albums)))
            }
        }

        return rows
    }

    func fetchMoodPlaylists() async throws -> [MoodPlaylistShelfItem] {
        let moodQueries: [(label: String, term: String)] = [
            ("Chill", "Chill"),
            ("Workout", "Workout"),
            ("Focus", "Focus"),
            ("Late Night", "Late Night")
        ]

        var items: [MoodPlaylistShelfItem] = []

        for query in moodQueries {
            var request = MusicCatalogSearchRequest(term: query.term, types: [Playlist.self])
            request.limit = 5
            let response = try await request.response()

            if let playlist = response.playlists.first {
                items.append(MoodPlaylistShelfItem(moodTitle: query.label, playlist: playlist))
            }
        }

        return items
    }

    func fetchRecentlyPlayedAlbums(limit: Int = 8) async throws -> [Album] {
        let authStatus = MusicAuthorization.currentStatus
        guard authStatus == .authorized else {
            throw AppleMusicRecommendationError.notAuthorized
        }

        var request = MusicRecentlyPlayedRequest<RecentlyPlayedMusicItem>()
        request.limit = max(1, min(limit, 10))

        let response = try await request.response()
        let albums = response.items.compactMap { item -> Album? in
            guard case let .album(album) = item else { return nil }
            return album
        }

        return Array(albums.uniquedByID().prefix(limit))
    }

    func loadTracks(for playlist: Playlist) async throws -> [SharedPlaylistTrack] {
        let loadedPlaylist = try await playlist.with([.tracks], preferredSource: .catalog)
        return Self.makeSharedTracks(from: loadedPlaylist)
    }

    func loadTracks(for album: Album) async throws -> [SharedPlaylistTrack] {
        let loadedAlbum = try await album.with([.tracks], preferredSource: .catalog)
        return Self.makeSharedTracks(from: loadedAlbum)
    }

    func play(playlist: Playlist) async throws {
        player.queue = .init(for: [playlist])
        try await player.prepareToPlay()
        try await player.play()
    }

    func play(album: Album) async throws {
        player.queue = .init(for: [album])
        try await player.prepareToPlay()
        try await player.play()
    }

    func play(station: Station) async throws {
        player.queue = .init(for: [station])
        try await player.prepareToPlay()
        try await player.play()
    }

    func playTracks(with ids: [String]) async throws {
        let musicIDs = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { MusicItemID($0) }

        guard !musicIDs.isEmpty else {
            throw AppleMusicRecommendationError.noPlayableTracks
        }

        var request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: musicIDs)
        request.limit = min(musicIDs.count, 25)
        let response = try await request.response()
        let songs = Array(response.items)

        guard !songs.isEmpty else {
            throw AppleMusicRecommendationError.noPlayableTracks
        }

        player.queue = .init(for: songs)
        try await player.prepareToPlay()
        try await player.play()
    }

    func addToLibrary(playlist: Playlist) async throws {
        try await MusicLibrary.shared.add(playlist)
    }

    func addToLibrary(album: Album) async throws {
        try await MusicLibrary.shared.add(album)
    }

    static func makeSharedPlaylistDocumentID(ownerUID: String, sourcePlaylistID: String) -> String {
        "\(ownerUID)_\(sourcePlaylistID.replacingOccurrences(of: "/", with: "_"))"
    }

    static func makeSharedTracks(from playlist: Playlist) -> [SharedPlaylistTrack] {
        let items = playlist.tracks?.compactMap { track -> SharedPlaylistTrack? in
            guard case .song(let song) = track else { return nil }

            let songID = "\(song.id)"
            return SharedPlaylistTrack(
                id: songID,
                title: song.title,
                artistName: song.artistName,
                albumTitle: song.albumTitle ?? "",
                songStoreID: songID,
                artworkURL: song.artwork?.url(width: 320, height: 320)?.absoluteString,
                durationText: Self.formatDuration(song.duration)
            )
        } ?? []

        return Array(items.prefix(25))
    }

    static func makeSharedTracks(from album: Album) -> [SharedPlaylistTrack] {
        let items = album.tracks?.compactMap { track -> SharedPlaylistTrack? in
            let songID = "\(track.id)"
            return SharedPlaylistTrack(
                id: songID,
                title: track.title,
                artistName: track.artistName,
                albumTitle: track.albumTitle ?? album.title,
                songStoreID: songID,
                artworkURL: track.artwork?.url(width: 320, height: 320)?.absoluteString
                    ?? album.artwork?.url(width: 320, height: 320)?.absoluteString,
                durationText: Self.formatDuration(track.duration)
            )
        } ?? []

        return Array(items.prefix(25))
    }

    static func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration else { return "" }
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private extension Sequence where Element: MusicItem & Identifiable {
    func uniquedByID() -> [Element] {
        var seen: Set<Element.ID> = []
        return filter { item in
            seen.insert(item.id).inserted
        }
    }
}
