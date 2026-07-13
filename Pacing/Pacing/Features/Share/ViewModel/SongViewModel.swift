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
        hasCompletedInitialLoad = false
        musicAuthorizationStatus = await musicService.requestAuthorizationIfNeeded()
        await syncMyPlaylistsIfPossible(showError: false)

        async let friendsTask: Void = loadFriendPlaylists(showError: false)
        async let recommendationsTask: Void = loadRecommendations()
        _ = await (friendsTask, recommendationsTask)
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
            friendSharedPlaylists = try await firestoreService.fetchFriendSharedPlaylists(currentUID: uid)
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
