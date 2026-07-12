import Foundation
import Combine
import FirebaseAuth
import MusicKit

@MainActor
final class ShareViewModel: ObservableObject {
    @Published var friendSharedPlaylists: [SharedPlaylistSummary] = []
    @Published var recommendedPlaylists: [Playlist] = []
    @Published var recommendedStations: [Station] = []
    @Published var musicAuthorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @Published var hasCatalogAccess: Bool = false
    @Published var isLoadingFriends: Bool = false
    @Published var isLoadingRecommendations: Bool = false
    @Published var isSyncingLibrary: Bool = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private let musicService = AppleMusicRecommendationService.shared

    func load() async {
        errorMessage = nil
        musicAuthorizationStatus = await musicService.requestAuthorizationIfNeeded()

        async let friendsTask: Void = loadFriendPlaylists()
        async let recommendationsTask: Void = loadRecommendations()
        async let syncTask: Void = syncMyPlaylistsIfPossible()

        _ = await (friendsTask, recommendationsTask, syncTask)
    }

    func reloadFriendsOnly() async {
        await loadFriendPlaylists()
    }

    func syncMyPlaylistsIfPossible() async {
        guard musicAuthorizationStatus == .authorized else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        isSyncingLibrary = true
        defer { isSyncingLibrary = false }

        let nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"

        do {
            try await musicService.syncCurrentUserPlaylists(uid: uid, nickname: nickname)
            await loadFriendPlaylists()
        } catch {
            errorMessage = "내 플레이리스트를 동기화하지 못했어요."
        }
    }

    func play(station: Station) async {
        do {
            try await musicService.play(station: station)
        } catch {
            errorMessage = "스테이션 재생을 시작하지 못했어요."
        }
    }

    private func loadFriendPlaylists() async {
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
            errorMessage = "친구 플레이리스트를 불러오지 못했어요."
        }
    }

    private func loadRecommendations() async {
        guard musicAuthorizationStatus == .authorized else {
            recommendedPlaylists = []
            recommendedStations = []
            hasCatalogAccess = false
            return
        }

        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }

        do {
            let subscription = try await musicService.currentSubscription()
            hasCatalogAccess = subscription.canPlayCatalogContent

            let bundle = try await musicService.fetchRecommendations()
            recommendedPlaylists = bundle.playlists
            recommendedStations = bundle.stations
        } catch {
            recommendedPlaylists = []
            recommendedStations = []
            hasCatalogAccess = false
            errorMessage = "Apple Music 추천을 불러오지 못했어요."
        }
    }
}
