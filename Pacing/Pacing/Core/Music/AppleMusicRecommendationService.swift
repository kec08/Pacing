import Foundation
import MusicKit

struct ShareRecommendationBundle {
    let playlists: [Playlist]
    let stations: [Station]
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

        var playlists: [Playlist] = []
        var stations: [Station] = []

        do {
            var request = MusicPersonalRecommendationsRequest()
            request.limit = limit
            let response = try await request.response()

            playlists = response.recommendations
                .flatMap { Array($0.playlists) }
                .uniquedByID()
                .prefix(limit)
                .map { $0 }

            stations = response.recommendations
                .flatMap { Array($0.stations) }
                .uniquedByID()
                .prefix(limit)
                .map { $0 }
        } catch {
            playlists = []
            stations = []
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

        return ShareRecommendationBundle(playlists: playlists, stations: stations)
    }

    func loadTracks(for playlist: Playlist) async throws -> [SharedPlaylistTrack] {
        let loadedPlaylist = try await playlist.with([.tracks], preferredSource: .catalog)
        return Self.makeSharedTracks(from: loadedPlaylist)
    }

    func play(playlist: Playlist) async throws {
        player.queue = .init(for: [playlist])
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
