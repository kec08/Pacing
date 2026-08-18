import Foundation
import MusicKit
import MediaPlayer
import UIKit

extension Notification.Name {
    static let applicationMusicPlayerQueueDidChange = Notification.Name("applicationMusicPlayerQueueDidChange")
}

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
    case catalogUnavailable
    case noPlayableTracks

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Apple Music 권한이 필요해요."
        case .subscriptionUnavailable:
            return "Apple Music 구독 상태를 확인해주세요."
        case .catalogUnavailable:
            return "Apple Music 추천을 일시적으로 불러올 수 없어요."
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

    /// 보관함 플레이리스트를 배치 끝까지 조회한다. 재생 선택 화면에서는 수를 자르지 않고,
    /// 공유 동기화처럼 상한이 필요한 호출만 `maximumCount`를 지정한다.
    func fetchLibraryPlaylists(pageSize: Int = 100, maximumCount: Int? = nil) async throws -> [Playlist] {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = pageSize
        var batch = try await request.response().items
        var playlists = Array(batch)

        while batch.hasNextBatch,
              maximumCount.map({ playlists.count < $0 }) ?? true,
              let nextBatch = try await batch.nextBatch(limit: pageSize) {
            batch = nextBatch
            playlists.append(contentsOf: nextBatch)
        }

        if let maximumCount {
            return Array(playlists.prefix(maximumCount))
        }
        return playlists
    }

    func syncCurrentUserPlaylists(uid: String, nickname: String, limit: Int = 30) async throws {
        let playlists = try await fetchLibraryPlaylists(maximumCount: limit)

        for playlist in playlists {
            let loadedPlaylist = try await playlist.with([.tracks], preferredSource: .library)
            // 개별 곡의 카탈로그 보강 실패가 대표 커버 동기화 전체를 막지 않도록 한다.
            let sharedTracks = await enrichedSharedTracks(from: loadedPlaylist)
            let artworkURL = Self.remoteArtworkURL(from: loadedPlaylist.artwork, width: 800, height: 800)
            let summary = SharedPlaylistSummary(
                id: Self.makeSharedPlaylistDocumentID(ownerUID: uid, sourcePlaylistID: "\(playlist.id)"),
                ownerUID: uid,
                ownerNickname: nickname,
                title: loadedPlaylist.name,
                subtitle: loadedPlaylist.curatorName ?? loadedPlaylist.shortDescription ?? "내 플레이리스트",
                // 플레이리스트 대표 커버만 저장한다. 수록곡 앨범 커버를 대신 쓰면
                // 다른 기기에서 대표 이미지와 곡 매핑이 달라질 수 있다.
                artworkURL: artworkURL,
                artworkData: await Self.encodedArtworkData(from: artworkURL),
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
        let didReceiveRecentlyPlayedResponse: Bool
        do {
            recentlyPlayedAlbums = try await fetchRecentlyPlayedAlbums(limit: limit)
            didReceiveRecentlyPlayedResponse = true
        } catch {
            // Keep recommendations available even if recent-played lookup fails.
            recentlyPlayedAlbums = []
            didReceiveRecentlyPlayedResponse = false
        }

        var playlists: [Playlist] = []
        let genreResult = await fetchGenreAlbumRows()
        let moodResult = await fetchMoodPlaylists()
        var didReceivePlaylistResponse = false

        do {
            var request = MusicPersonalRecommendationsRequest()
            request.limit = limit
            let response = try await request.response()

            playlists = response.recommendations
                .flatMap { Array($0.playlists) }
                .uniquedByID()
                .prefix(limit)
                .map { $0 }
            didReceivePlaylistResponse = true

        } catch {
            playlists = []
        }

        if playlists.isEmpty {
            do {
                var chartsRequest = MusicCatalogChartsRequest(types: [Playlist.self])
                chartsRequest.limit = limit
                let charts = try await chartsRequest.response()
                playlists = charts.playlistCharts
                    .flatMap { Array($0.items) }
                    .uniquedByID()
                    .prefix(limit)
                    .map { $0 }
                didReceivePlaylistResponse = true
            } catch {
                playlists = []
            }
        }

        guard didReceiveRecentlyPlayedResponse ||
            genreResult.didReceiveResponse ||
            moodResult.didReceiveResponse ||
            didReceivePlaylistResponse else {
            throw AppleMusicRecommendationError.catalogUnavailable
        }

        return ShareRecommendationBundle(
            recentlyPlayedAlbums: recentlyPlayedAlbums,
            playlists: playlists,
            genreAlbumRows: genreResult.items,
            moodPlaylists: moodResult.items
        )
    }

    private func fetchGenreAlbumRows() async -> (items: [GenreAlbumRow], didReceiveResponse: Bool) {
        let genreQueries: [(label: String, term: String)] = [
            ("R&B", "R&B"),
            ("인디", "Indie"),
            ("힙합", "Hip-Hop"),
            ("K-Pop", "K-Pop")
        ]

        var rows: [GenreAlbumRow] = []
        var didReceiveResponse = false

        for query in genreQueries {
            do {
                var request = MusicCatalogSearchRequest(term: query.term, types: [Album.self])
                request.limit = 5
                let response = try await request.response()
                didReceiveResponse = true

                let albums = response.albums.prefix(6).map {
                    GenreAlbumShelfItem(genreTitle: query.label, album: $0)
                }

                if !albums.isEmpty {
                    rows.append(GenreAlbumRow(genreTitle: query.label, albums: Array(albums)))
                }
            } catch {
                continue
            }
        }

        return (rows, didReceiveResponse)
    }

    private func fetchMoodPlaylists() async -> (items: [MoodPlaylistShelfItem], didReceiveResponse: Bool) {
        let moodQueries: [(label: String, term: String)] = [
            ("Chill", "Chill"),
            ("Workout", "Workout"),
            ("Focus", "Focus"),
            ("Late Night", "Late Night")
        ]

        var items: [MoodPlaylistShelfItem] = []
        var didReceiveResponse = false

        for query in moodQueries {
            do {
                var request = MusicCatalogSearchRequest(term: query.term, types: [Playlist.self])
                request.limit = 5
                let response = try await request.response()
                didReceiveResponse = true

                if let playlist = response.playlists.first {
                    items.append(MoodPlaylistShelfItem(moodTitle: query.label, playlist: playlist))
                }
            } catch {
                continue
            }
        }

        return (items, didReceiveResponse)
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
        let loadedPlaylist = try await playlist.with([.tracks], preferredSource: .catalog)
        let songs = loadedPlaylist.tracks?.compactMap { track -> Song? in
            if case .song(let song) = track { return song }
            return nil
        } ?? []
        guard !songs.isEmpty else { throw AppleMusicRecommendationError.noPlayableTracks }
        try await startPlayback(with: .init(for: songs))
    }

    func play(album: Album) async throws {
        let loadedAlbum = try await album.with([.tracks], preferredSource: .catalog)
        let songs = loadedAlbum.tracks?.compactMap { track -> Song? in
            if case .song(let song) = track { return song }
            return nil
        } ?? []
        guard !songs.isEmpty else { throw AppleMusicRecommendationError.noPlayableTracks }
        try await startPlayback(with: .init(for: songs))
    }

    func play(station: Station) async throws {
        try await startPlayback(with: .init(for: [station]))
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

        try await startPlayback(with: .init(for: songs))
    }

    func play(sharedTracks: [SharedPlaylistTrack]) async throws {
        let songs = try await resolveCatalogSongs(for: sharedTracks)
        guard !songs.isEmpty else {
            throw AppleMusicRecommendationError.noPlayableTracks
        }

        try await startPlayback(with: .init(for: songs))
    }

    /// 선택한 곡부터 목록의 마지막 곡까지 순서대로 재생한다.
    /// 선택 곡이 재생 불가한 경우 다음 곡으로 건너뛰지 않고 오류를 반환한다.
    func play(sharedTracks: [SharedPlaylistTrack], startingAt trackID: String) async throws {
        guard let startIndex = sharedTracks.firstIndex(where: { $0.id == trackID }) else {
            throw AppleMusicRecommendationError.noPlayableTracks
        }

        let resolvedSongsByTrackID = try await resolveCatalogSongMatches(for: sharedTracks)

        guard let targetSong = resolvedSongsByTrackID[trackID] else {
            throw AppleMusicRecommendationError.noPlayableTracks
        }

        let songs = sharedTracks.compactMap { resolvedSongsByTrackID[$0.id] }
        guard !songs.isEmpty else {
            throw AppleMusicRecommendationError.noPlayableTracks
        }

        try await startPlayback(with: .init(for: songs, startingAt: targetSong))
    }

    func play(sharedTrack: SharedPlaylistTrack) async throws {
        let songs = try await resolveCatalogSongs(for: [sharedTrack])
        guard let song = songs.first else {
            throw AppleMusicRecommendationError.noPlayableTracks
        }

        try await startPlayback(with: .init(for: [song]))
    }

    private func startPlayback(with queue: ApplicationMusicPlayer.Queue) async throws {
        // 러닝 시트의 시스템 플레이어가 남아 있으면 탭마다 서로 다른 곡을 표시할 수 있다.
        // 새 재생 경로를 시작하기 전에 이전 경로를 명시적으로 멈춘다.
        MPMusicPlayerController.systemMusicPlayer.pause()
        player.queue = queue
        NotificationCenter.default.post(name: .applicationMusicPlayerQueueDidChange, object: player)
        try await player.prepareToPlay()
        try await player.play()
    }

    func prepareSharedTracksForPlayback(_ tracks: [SharedPlaylistTrack]) async -> [SharedPlaylistTrack] {
        guard !tracks.isEmpty else { return [] }

        let resolvedSongsByTrackID: [String: Song]
        if let resolvedSongs = try? await resolveCatalogSongMatches(for: tracks) {
            resolvedSongsByTrackID = resolvedSongs
        } else {
            resolvedSongsByTrackID = await resolveFallbackCatalogSongMatches(for: tracks)
        }

        return tracks.map { track in
            guard let song = resolvedSongsByTrackID[track.id] else { return track }

            return SharedPlaylistTrack(
                id: track.id,
                title: track.title,
                artistName: track.artistName,
                albumTitle: track.albumTitle,
                songStoreID: "\(song.id)",
                artworkURL: Self.isRemoteArtworkURL(track.artworkURL)
                    ? track.artworkURL
                    : Self.remoteArtworkURL(from: song.artwork, width: 320, height: 320),
                durationText: track.durationText
            )
        }
    }

    func resolvedArtworkURLs(for songs: [Song]) async -> [String: String] {
        guard !songs.isEmpty else { return [:] }

        var artworkURLsBySongID: [String: String] = [:]

        for song in songs {
            let songID = "\(song.id)"

            if let artworkURL = Self.remoteArtworkURL(from: song.artwork, width: 900, height: 900) {
                artworkURLsBySongID[songID] = artworkURL
                continue
            }

            guard let matchedSong = try? await searchCatalogSong(
                title: song.title,
                artist: song.artistName
            ),
            let artworkURL = Self.remoteArtworkURL(from: matchedSong.artwork, width: 900, height: 900)
            else {
                continue
            }

            artworkURLsBySongID[songID] = artworkURL
        }

        return artworkURLsBySongID
    }

    /// Firestore에 저장된 최근 재생 이력은 오래된 데이터에 커버 URL이 없을 수 있어
    /// 제목·아티스트로 카탈로그를 다시 찾아 대표 커버를 보완한다.
    func resolvedRecentSongArtworkURL(title: String, artistName: String) async -> String? {
        guard let song = try? await searchCatalogSong(title: title, artist: artistName) else {
            return nil
        }

        return Self.remoteArtworkURL(from: song.artwork, width: 900, height: 900)
    }

    func resolvedLibraryPlaylistArtworkURLs(for playlists: [Playlist]) async -> [String: String] {
        guard !playlists.isEmpty else { return [:] }

        var artworkURLsByPlaylistID: [String: String] = [:]

        for playlist in playlists {
            let playlistID = "\(playlist.id)"

            if let artworkURL = Self.remoteArtworkURL(from: playlist.artwork, width: 900, height: 900) {
                artworkURLsByPlaylistID[playlistID] = artworkURL
                continue
            }

        }

        return artworkURLsByPlaylistID
    }

    /// 추천 응답에 대표 이미지가 누락된 경우, 카탈로그에서 같은 이름의 플레이리스트 커버를 보완한다.
    func resolvedRecommendationPlaylistArtworkURLs(for playlists: [Playlist]) async -> [String: String] {
        guard !playlists.isEmpty else { return [:] }

        var artworkURLsByPlaylistID: [String: String] = [:]

        for playlist in playlists {
            let playlistID = "\(playlist.id)"

            if let artworkURL = Self.remoteArtworkURL(from: playlist.artwork, width: 900, height: 900) {
                artworkURLsByPlaylistID[playlistID] = artworkURL
                continue
            }

            guard !playlist.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            do {
                var request = MusicCatalogSearchRequest(term: playlist.name, types: [Playlist.self])
                request.limit = 5
                let response = try await request.response()

                if let matchedPlaylist = response.playlists.first(where: {
                    $0.name.caseInsensitiveCompare(playlist.name) == .orderedSame
                }) ?? response.playlists.first,
                   let artworkURL = Self.remoteArtworkURL(from: matchedPlaylist.artwork, width: 900, height: 900) {
                    artworkURLsByPlaylistID[playlistID] = artworkURL
                }
            } catch {
                continue
            }
        }

        return artworkURLsByPlaylistID
    }

    func addToLibrary(playlist: Playlist) async throws {
        try await MusicLibrary.shared.add(playlist)
    }

    func addToLibrary(album: Album) async throws {
        try await MusicLibrary.shared.add(album)
    }

    /// 친구가 공유한 수록곡으로 사용자의 Apple Music 보관함에 새 플레이리스트를 만든다.
    func createLibraryPlaylist(
        name: String,
        authorDisplayName: String,
        sharedTracks: [SharedPlaylistTrack]
    ) async throws -> String {
        let songs = try await resolveCatalogSongs(for: sharedTracks)
        guard !songs.isEmpty else {
            throw AppleMusicRecommendationError.noPlayableTracks
        }

        let playlist = try await MusicLibrary.shared.createPlaylist(
            name: name,
            description: nil,
            authorDisplayName: authorDisplayName,
            items: songs
        )
        return "\(playlist.id)"
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
                artworkURL: Self.remoteArtworkURL(from: song.artwork, width: 320, height: 320),
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
                artworkURL: Self.remoteArtworkURL(from: track.artwork, width: 320, height: 320)
                    ?? Self.remoteArtworkURL(from: album.artwork, width: 320, height: 320),
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

    static func isRemoteArtworkURL(_ urlString: String?) -> Bool {
        guard let urlString,
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased()
        else {
            return false
        }

        return scheme == "https" || scheme == "http"
    }

    static func remoteArtworkURL(from artwork: Artwork?, width: Int, height: Int) -> String? {
        guard let urlString = artwork?.url(width: width, height: height)?.absoluteString,
              isRemoteArtworkURL(urlString)
        else {
            return nil
        }

        return urlString
    }

    private static func encodedArtworkData(from urlString: String?) async -> String? {
        guard let urlString,
              let url = URL(string: urlString),
              ["https", "http"].contains(url.scheme?.lowercased() ?? "")
        else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let response = response as? HTTPURLResponse,
                  200..<300 ~= response.statusCode,
                  let image = UIImage(data: data)
            else {
                return nil
            }

            let targetSize = CGSize(width: 400, height: 400)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            return resizedImage.jpegData(compressionQuality: 0.72)?.base64EncodedString()
        } catch {
            return nil
        }
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

        let fallbackTracks = tracks.filter { resolvedSongsByTrackID[$0.id] == nil }
        let fallbackMatches = await resolveFallbackCatalogSongMatches(for: fallbackTracks)
        for (trackID, song) in fallbackMatches {
            resolvedCatalogSongsByStoreID.setObject(
                CachedCatalogSong(song),
                forKey: "\(song.id)" as NSString
            )
            resolvedSongsByTrackID[trackID] = song
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

    private func resolveFallbackCatalogSongMatches(
        for tracks: [SharedPlaylistTrack],
        maximumConcurrentRequests: Int = 4
    ) async -> [String: Song] {
        guard !tracks.isEmpty else { return [:] }

        var resolvedSongsByTrackID: [String: Song] = [:]
        let batches = stride(from: 0, to: tracks.count, by: maximumConcurrentRequests).map {
            Array(tracks[$0..<min($0 + maximumConcurrentRequests, tracks.count)])
        }

        for batch in batches {
            let matches = await withTaskGroup(of: (String, Song?).self, returning: [(String, Song)].self) { group in
                for track in batch {
                    group.addTask { [self] in
                        let song = try? await searchCatalogSong(title: track.title, artist: track.artistName)
                        return (track.id, song)
                    }
                }

                var batchMatches: [(String, Song)] = []
                for await (trackID, song) in group {
                    if let song {
                        batchMatches.append((trackID, song))
                    }
                }
                return batchMatches
            }

            for (trackID, song) in matches {
                resolvedSongsByTrackID[trackID] = song
            }
        }

        return resolvedSongsByTrackID
    }

    private func enrichedSharedTracks(from playlist: Playlist) async -> [SharedPlaylistTrack] {
        let baseTracks = Self.makeSharedTracks(from: playlist)
        guard !baseTracks.isEmpty else { return [] }
        guard let resolvedSongsByTrackID = try? await resolveCatalogSongMatches(for: baseTracks) else {
            return baseTracks
        }

        return baseTracks.map { track in
            guard !Self.isRemoteArtworkURL(track.artworkURL),
                  let song = resolvedSongsByTrackID[track.id]
            else {
                return track
            }

            return SharedPlaylistTrack(
                id: track.id,
                title: track.title,
                artistName: track.artistName,
                albumTitle: track.albumTitle,
                songStoreID: "\(song.id)",
                artworkURL: Self.remoteArtworkURL(from: song.artwork, width: 320, height: 320),
                durationText: track.durationText
            )
        }
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
