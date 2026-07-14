import Foundation
import Combine
import FirebaseAuth
import MusicKit

@MainActor
final class SongViewModel: ObservableObject {
    @Published var friendSharedPlaylists: [SharedPlaylistSummary] = []
    @Published var recentlyPlayedAlbums: [Album] = []
    @Published var recommendedPlaylists: [Playlist] = []
    @Published var genreAlbumRows: [GenreAlbumRow] = []
    @Published var moodPlaylists: [MoodPlaylistShelfItem] = []
    @Published var musicAuthorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @Published var hasCatalogAccess: Bool = false
    @Published var isLoadingFriends: Bool = false
    @Published var isLoadingRecentlyPlayedAlbums: Bool = false
    @Published var isLoadingRecommendations: Bool = false
    @Published var isSyncingLibrary: Bool = false
    @Published var hasCompletedInitialLoad: Bool = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private let musicService = AppleMusicRecommendationService.shared

    func load() async {
        errorMessage = nil
        let isFirstLoad = !hasCompletedInitialLoad
        if isFirstLoad {
            hasCompletedInitialLoad = false
        }
        musicAuthorizationStatus = await musicService.requestAuthorizationIfNeeded()

        async let recommendationsTask: Void = loadRecommendations()

        if musicAuthorizationStatus == .authorized {
            await syncMyPlaylistsIfPossible(showError: false)
        }

        await loadFriendPlaylists(showError: false)
        await recommendationsTask
        hasCompletedInitialLoad = true
    }

    func reloadFriendsOnly() async {
        await loadFriendPlaylists()
    }

    func syncMyPlaylistsIfPossible() async {
        await syncMyPlaylistsIfPossible(showError: true)
    }

    func syncMyPlaylistsIfPossible(showError: Bool) async {
        guard musicAuthorizationStatus == .authorized else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        isSyncingLibrary = true
        defer { isSyncingLibrary = false }

        let nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"

        do {
            try await musicService.syncCurrentUserPlaylists(uid: uid, nickname: nickname)
            await loadFriendPlaylists(showError: showError)
        } catch {
            if showError {
                errorMessage = "내 플레이리스트를 동기화하지 못했어요."
            }
        }
    }

    private func loadFriendPlaylists(showError: Bool = true) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            friendSharedPlaylists = []
            return
        }

        isLoadingFriends = true
        defer { isLoadingFriends = false }

        do {
            let fetchedPlaylists = try await firestoreService.fetchFriendSharedPlaylists(currentUID: uid)
            var enrichedPlaylists: [SharedPlaylistSummary] = []
            enrichedPlaylists.reserveCapacity(fetchedPlaylists.count)

            for playlist in fetchedPlaylists {
                let enrichedPlaylist = await musicService.enrichedSharedPlaylistSummary(playlist)
                enrichedPlaylists.append(enrichedPlaylist)
            }

            friendSharedPlaylists = enrichedPlaylists

            let artworkURLs = enrichedPlaylists.compactMap(\.effectiveArtworkURL)
            Task {
                await ArtworkImageStore.shared.prefetch(urlStrings: artworkURLs)
            }
        } catch {
            friendSharedPlaylists = []
            if showError {
                errorMessage = "친구 플레이리스트를 불러오지 못했어요."
            }
        }
    }

    private func loadRecommendations() async {
        guard musicAuthorizationStatus == .authorized else {
            recentlyPlayedAlbums = []
            recommendedPlaylists = []
            genreAlbumRows = []
            moodPlaylists = []
            hasCatalogAccess = false
            return
        }

        isLoadingRecentlyPlayedAlbums = true
        isLoadingRecommendations = true
        defer {
            isLoadingRecentlyPlayedAlbums = false
            isLoadingRecommendations = false
        }

        do {
            let subscription = try await musicService.currentSubscription()
            hasCatalogAccess = subscription.canPlayCatalogContent

            let bundle = try await musicService.fetchRecommendations()
            recentlyPlayedAlbums = bundle.recentlyPlayedAlbums
            recommendedPlaylists = bundle.playlists
            genreAlbumRows = bundle.genreAlbumRows
            moodPlaylists = bundle.moodPlaylists

            let artworkURLs =
                bundle.recentlyPlayedAlbums.compactMap { $0.artwork?.url(width: 900, height: 900)?.absoluteString } +
                bundle.playlists.compactMap { $0.artwork?.url(width: 900, height: 900)?.absoluteString } +
                bundle.genreAlbumRows
                    .flatMap(\.albums)
                    .compactMap { $0.album.artwork?.url(width: 900, height: 900)?.absoluteString } +
                bundle.moodPlaylists.compactMap { $0.playlist.artwork?.url(width: 900, height: 900)?.absoluteString }

            Task {
                await ArtworkImageStore.shared.prefetch(urlStrings: artworkURLs)
            }
        } catch {
            recentlyPlayedAlbums = []
            recommendedPlaylists = []
            genreAlbumRows = []
            moodPlaylists = []
            hasCatalogAccess = false
            errorMessage = "Apple Music 추천을 불러오지 못했어요."
        }
    }
}
