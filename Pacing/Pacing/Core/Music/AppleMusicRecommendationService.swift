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
    private let resolvedCatalogSongsByStoreID = NSCache<NSString, CachedCatalogSong>()
    private let resolvedCatalogSongsByQuery = NSCache<NSString, CachedCatalogSong>()

    private init() {
        resolvedCatalogSongsByStoreID.countLimit = 180
        resolvedCatalogSongsByQuery.countLimit = 220
    }

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
            let sharedTracks = try await enrichedSharedTracks(from: loadedPlaylist)
            let summary = SharedPlaylistSummary(
                id: Self.makeSharedPlaylistDocumentID(ownerUID: uid, sourcePlaylistID: "\(playlist.id)"),
                ownerUID: uid,
                ownerNickname: nickname,
                title: loadedPlaylist.name,
                subtitle: loadedPlaylist.curatorName ?? loadedPlaylist.shortDescription ?? "내 플레이리스트",
                artworkURL: try await resolvedPlaylistArtworkURL(
                    playlistArtworkURL: loadedPlaylist.artwork?.url(width: 800, height: 800)?.absoluteString,
                    tracks: sharedTracks
                ),
                sourcePlaylistID: "\(loadedPlaylist.id)",
                sourcePlaylistURL: loadedPlaylist.url?.absoluteString,
                trackCount: loadedPlaylist.tracks?.count ?? 0,
                updatedAt: Date(),
                tracks: sharedTracks
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

    func play(sharedTracks: [SharedPlaylistTrack]) async throws {
        let songs = try await resolveCatalogSongs(for: sharedTracks)
        guard !songs.isEmpty else {
            throw AppleMusicRecommendationError.noPlayableTracks
        }

        player.queue = .init(for: songs)
        try await player.prepareToPlay()
        try await player.play()
    }

    func play(sharedTrack: SharedPlaylistTrack) async throws {
        let songs = try await resolveCatalogSongs(for: [sharedTrack])
        guard let song = songs.first else {
            throw AppleMusicRecommendationError.noPlayableTracks
        }

        player.queue = .init(for: [song])
        try await player.prepareToPlay()
        try await player.play()
    }

    func prepareSharedTracksForPlayback(_ tracks: [SharedPlaylistTrack]) async -> [SharedPlaylistTrack] {
        guard !tracks.isEmpty else { return [] }

        guard let resolvedSongsByTrackID = try? await resolveCatalogSongMatches(for: tracks) else {
            return tracks
        }

        return tracks.map { track in
            guard let song = resolvedSongsByTrackID[track.id] else { return track }

            return SharedPlaylistTrack(
                id: track.id,
                title: track.title,
                artistName: track.artistName,
                albumTitle: track.albumTitle,
                songStoreID: "\(song.id)",
                artworkURL: track.artworkURL ?? song.artwork?.url(width: 320, height: 320)?.absoluteString,
                durationText: track.durationText
            )
        }
    }

    func enrichedSharedPlaylistSummary(_ summary: SharedPlaylistSummary) async -> SharedPlaylistSummary {
        var updatedTracks = summary.tracks
        var resolvedArtworkCount = 0

        for index in updatedTracks.indices {
            let track = updatedTracks[index]
            let hasArtwork = !(track.artworkURL ?? "").isEmpty

            if hasArtwork {
                continue
            }

            // 목록 진입 시 카탈로그 요청이 과도하게 늘어나지 않도록, 먼저 보이는 곡의 커버만 보강한다.
            guard resolvedArtworkCount < 8 else { break }
            resolvedArtworkCount += 1

            guard let song = try? await searchCatalogSong(
                title: track.title,
                artist: track.artistName
            ) else {
                continue
            }

            let artworkURL = song.artwork?.url(width: 320, height: 320)?.absoluteString
            updatedTracks[index] = SharedPlaylistTrack(
                id: track.id,
                title: track.title,
                artistName: track.artistName,
                albumTitle: track.albumTitle,
                songStoreID: "\(song.id)",
                artworkURL: artworkURL,
                durationText: track.durationText
            )
        }

        let summaryArtworkURL: String?
        if let artworkURL = summary.artworkURL, !artworkURL.isEmpty {
            summaryArtworkURL = artworkURL
        } else {
            summaryArtworkURL = updatedTracks.first(where: { !($0.artworkURL ?? "").isEmpty })?.artworkURL
        }

        return SharedPlaylistSummary(
            id: summary.id,
            ownerUID: summary.ownerUID,
            ownerNickname: summary.ownerNickname,
            title: summary.title,
            subtitle: summary.subtitle,
            artworkURL: summaryArtworkURL,
            sourcePlaylistID: summary.sourcePlaylistID,
            sourcePlaylistURL: summary.sourcePlaylistURL,
            trackCount: summary.trackCount,
            updatedAt: summary.updatedAt,
            tracks: updatedTracks
        )
    }

    func resolvedArtworkURLs(for songs: [Song]) async -> [String: String] {
        guard !songs.isEmpty else { return [:] }

        var artworkURLsBySongID: [String: String] = [:]

        for song in songs {
            let songID = "\(song.id)"

            if let artworkURL = song.artwork?.url(width: 900, height: 900)?.absoluteString,
               !artworkURL.isEmpty {
                artworkURLsBySongID[songID] = artworkURL
                continue
            }

            guard let matchedSong = try? await searchCatalogSong(
                title: song.title,
                artist: song.artistName
            ),
            let artworkURL = matchedSong.artwork?.url(width: 900, height: 900)?.absoluteString,
            !artworkURL.isEmpty
            else {
                continue
            }

            artworkURLsBySongID[songID] = artworkURL
        }

        return artworkURLsBySongID
    }

    func resolvedLibraryPlaylistArtworkURLs(for playlists: [Playlist]) async -> [String: String] {
        guard !playlists.isEmpty else { return [:] }

        var artworkURLsByPlaylistID: [String: String] = [:]

        for playlist in playlists {
            let playlistID = "\(playlist.id)"

            if let artworkURL = playlist.artwork?.url(width: 900, height: 900)?.absoluteString,
               !artworkURL.isEmpty {
                artworkURLsByPlaylistID[playlistID] = artworkURL
                continue
            }

            guard let loadedPlaylist = try? await playlist.with([.tracks], preferredSource: .library) else {
                continue
            }

            guard let sharedTracks = try? await enrichedSharedTracks(from: loadedPlaylist),
                  let artworkURL = sharedTracks.first(where: { ($0.artworkURL ?? "").isEmpty == false })?.artworkURL,
                  !artworkURL.isEmpty
            else {
                continue
            }

            artworkURLsByPlaylistID[playlistID] = artworkURL
        }

        return artworkURLsByPlaylistID
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

    private func resolveCatalogSongs(for tracks: [SharedPlaylistTrack]) async throws -> [Song] {
        let resolvedSongsByTrackID = try await resolveCatalogSongMatches(for: tracks)
        return tracks.compactMap { resolvedSongsByTrackID[$0.id] }
    }

    private func resolveCatalogSongMatches(for tracks: [SharedPlaylistTrack]) async throws -> [String: Song] {
        guard !tracks.isEmpty else { return [:] }

        var resolvedSongsByTrackID: [String: Song] = [:]
        var unresolvedTracks: [SharedPlaylistTrack] = []

        for track in tracks {
            guard let songStoreID = track.songStoreID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !songStoreID.isEmpty else {
                unresolvedTracks.append(track)
                continue
            }

            if let cachedSong = resolvedCatalogSongsByStoreID.object(forKey: songStoreID as NSString)?.song {
                resolvedSongsByTrackID[track.id] = cachedSong
            } else {
                unresolvedTracks.append(track)
            }
        }

        let unresolvedStoreIDs = Array(Set(unresolvedTracks.compactMap { track -> String? in
            guard let songStoreID = track.songStoreID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !songStoreID.isEmpty else { return nil }
            return songStoreID
        }))

        if !unresolvedStoreIDs.isEmpty {
            var request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                memberOf: unresolvedStoreIDs.map { MusicItemID($0) }
            )
            request.limit = min(unresolvedStoreIDs.count, 25)

            if let response = try? await request.response() {
                let fetchedSongsByID: [String: Song] = Dictionary(
                    uniqueKeysWithValues: response.items.map { ("\($0.id)", $0) }
                )
                for (songID, song) in fetchedSongsByID {
                    resolvedCatalogSongsByStoreID.setObject(CachedCatalogSong(song), forKey: songID as NSString)
                }

                for track in unresolvedTracks {
                    guard let songStoreID = track.songStoreID?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !songStoreID.isEmpty,
                          let song = fetchedSongsByID[songStoreID] else { continue }
                    resolvedSongsByTrackID[track.id] = song
                }
            }
        }

        for track in tracks where resolvedSongsByTrackID[track.id] == nil {
            if let fallbackSong = try await searchCatalogSong(title: track.title, artist: track.artistName) {
                resolvedCatalogSongsByStoreID.setObject(
                    CachedCatalogSong(fallbackSong),
                    forKey: "\(fallbackSong.id)" as NSString
                )
                resolvedSongsByTrackID[track.id] = fallbackSong
            }
        }

        return resolvedSongsByTrackID
    }

    private func searchCatalogSong(title: String, artist: String) async throws -> Song? {
        let query = [title, artist]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !query.isEmpty else { return nil }

        let cacheKey = normalizeSongText(title) + "|" + normalizeSongText(artist)
        if let cachedSong = resolvedCatalogSongsByQuery.object(forKey: cacheKey as NSString)?.song {
            return cachedSong
        }

        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 10
        let response = try await request.response()

        let normalizedTitle = normalizeSongText(title)
        let normalizedArtist = normalizeSongText(artist)

        if let exactMatch = response.songs.first(where: { song in
            normalizeSongText(song.title) == normalizedTitle &&
            normalizeSongText(song.artistName) == normalizedArtist
        }) {
            resolvedCatalogSongsByQuery.setObject(CachedCatalogSong(exactMatch), forKey: cacheKey as NSString)
            return exactMatch
        }

        if let titleMatch = response.songs.first(where: { song in
            normalizeSongText(song.title) == normalizedTitle
        }) {
            resolvedCatalogSongsByQuery.setObject(CachedCatalogSong(titleMatch), forKey: cacheKey as NSString)
            return titleMatch
        }

        if let firstSong = response.songs.first {
            resolvedCatalogSongsByQuery.setObject(CachedCatalogSong(firstSong), forKey: cacheKey as NSString)
            return firstSong
        }

        return nil
    }

    private func normalizeSongText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func enrichedSharedTracks(from playlist: Playlist) async throws -> [SharedPlaylistTrack] {
        let baseTracks = Self.makeSharedTracks(from: playlist)
        guard !baseTracks.isEmpty else { return [] }

        var enrichedTracks = baseTracks

        for index in enrichedTracks.indices {
            if enrichedTracks[index].artworkURL != nil {
                continue
            }

            guard let song = try await searchCatalogSong(
                title: enrichedTracks[index].title,
                artist: enrichedTracks[index].artistName
            ) else {
                continue
            }

            enrichedTracks[index] = SharedPlaylistTrack(
                id: enrichedTracks[index].id,
                title: enrichedTracks[index].title,
                artistName: enrichedTracks[index].artistName,
                albumTitle: enrichedTracks[index].albumTitle,
                songStoreID: "\(song.id)",
                artworkURL: song.artwork?.url(width: 320, height: 320)?.absoluteString,
                durationText: enrichedTracks[index].durationText
            )

            if index >= 4 && enrichedTracks.contains(where: { $0.artworkURL != nil }) {
                break
            }
        }

        return enrichedTracks
    }

    private func resolvedPlaylistArtworkURL(
        playlistArtworkURL: String?,
        tracks: [SharedPlaylistTrack]
    ) async throws -> String? {
        if let playlistArtworkURL, !playlistArtworkURL.isEmpty {
            return playlistArtworkURL
        }

        if let trackArtworkURL = tracks.first(where: { ($0.artworkURL ?? "").isEmpty == false })?.artworkURL {
            return trackArtworkURL
        }

        return nil
    }
}

private final class CachedCatalogSong: NSObject {
    let song: Song

    init(_ song: Song) {
        self.song = song
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
