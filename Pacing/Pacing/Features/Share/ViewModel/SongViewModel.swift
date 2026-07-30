import Combine
import FirebaseAuth
import Foundation
import MusicKit

@MainActor
final class SongViewModel: ObservableObject {
    @Published var friendSharedPlaylists: [SharedPlaylistSummary] = []
    @Published var recentlyPlayedAlbums: [Album] = []
    @Published var recommendedPlaylists: [Playlist] = []
    @Published var genreAlbumRows: [GenreAlbumRow] = []
    @Published var moodPlaylists: [MoodPlaylistShelfItem] = []
    @Published private(set) var recommendationArtworkURLsByPlaylistID: [String: String] = [:]
    @Published var musicAuthorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @Published var hasCatalogAccess: Bool = false
    @Published var isLoadingFriends: Bool = false
    @Published var isLoadingRecentlyPlayedAlbums: Bool = false
    @Published var isLoadingRecommendations: Bool = false
    @Published var hasCompletedInitialLoad: Bool = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private let musicService = AppleMusicRecommendationService.shared
    private let recommendationRetryDelays: [UInt64] = [600_000_000, 1_200_000_000]
    private let backgroundRecommendationRetryDelays: [UInt64] = [2_000_000_000, 4_000_000_000, 8_000_000_000]
    private var activeRecommendationLoadID: UUID?
    private var backgroundRecommendationRetryCount = 0

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

    func syncMyPlaylistsIfPossible(showError: Bool) async {
        guard musicAuthorizationStatus == .authorized else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

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

    private func loadRecommendations(isBackgroundRetry: Bool = false) async {
        guard musicAuthorizationStatus == .authorized else {
            recentlyPlayedAlbums = []
            recommendedPlaylists = []
            genreAlbumRows = []
            moodPlaylists = []
            recommendationArtworkURLsByPlaylistID = [:]
            hasCatalogAccess = false
            return
        }

        if !isBackgroundRetry {
            backgroundRecommendationRetryCount = 0
        }

        let loadID = UUID()
        activeRecommendationLoadID = loadID
        isLoadingRecentlyPlayedAlbums = true
        isLoadingRecommendations = true
        var keepsLoadingForBackgroundRetry = false
        defer {
            if activeRecommendationLoadID == loadID && !keepsLoadingForBackgroundRetry {
                isLoadingRecentlyPlayedAlbums = false
                isLoadingRecommendations = false
            }
        }

        do {
            let result = try await fetchRecommendationsWithRetry()
            guard activeRecommendationLoadID == loadID else { return }

            hasCatalogAccess = result.subscription.canPlayCatalogContent
            recentlyPlayedAlbums = result.bundle.recentlyPlayedAlbums
            recommendedPlaylists = result.bundle.playlists
            genreAlbumRows = result.bundle.genreAlbumRows
            moodPlaylists = result.bundle.moodPlaylists
            recommendationArtworkURLsByPlaylistID = await musicService.resolvedCatalogPlaylistArtworkURLs(
                for: result.bundle.playlists
            )

            let artworkURLs =
                result.bundle.recentlyPlayedAlbums.compactMap { $0.artwork?.url(width: 900, height: 900)?.absoluteString } +
                result.bundle.playlists.compactMap { $0.artwork?.url(width: 900, height: 900)?.absoluteString } +
                result.bundle.genreAlbumRows
                .flatMap(\.albums)
                .compactMap { $0.album.artwork?.url(width: 900, height: 900)?.absoluteString } +
                result.bundle.moodPlaylists.compactMap { $0.playlist.artwork?.url(width: 900, height: 900)?.absoluteString }

            Task {
                await ArtworkImageStore.shared.prefetch(urlStrings: artworkURLs)
            }
        } catch {
            guard activeRecommendationLoadID == loadID else { return }

            recentlyPlayedAlbums = []
            recommendedPlaylists = []
            genreAlbumRows = []
            moodPlaylists = []
            recommendationArtworkURLsByPlaylistID = [:]
            hasCatalogAccess = false

            if scheduleBackgroundRecommendationRetry(after: error, for: loadID) {
                keepsLoadingForBackgroundRetry = true
                return
            }

            if shouldPresentRecommendationError(for: error) {
                errorMessage = "Apple Music 추천을 불러오지 못했어요. 잠시 후 다시 시도해주세요."
            }
        }
    }

    private func fetchRecommendationsWithRetry() async throws -> (subscription: MusicSubscription, bundle: ShareRecommendationBundle) {
        var lastError: Error?

        for attempt in 0 ... recommendationRetryDelays.count {
            do {
                let subscription = try await musicService.currentSubscription()
                let bundle = try await musicService.fetchRecommendations()
                return (subscription, bundle)
            } catch let error as AppleMusicRecommendationError {
                switch error {
                case .notAuthorized, .subscriptionUnavailable:
                    throw error
                case .catalogUnavailable, .noPlayableTracks:
                    lastError = error
                }
            } catch {
                lastError = error
            }

            guard attempt < recommendationRetryDelays.count else { break }
            try? await Task.sleep(nanoseconds: recommendationRetryDelays[attempt])
        }

        throw lastError ?? AppleMusicRecommendationError.subscriptionUnavailable
    }

    private func scheduleBackgroundRecommendationRetry(after error: Error, for loadID: UUID) -> Bool {
        guard shouldRetryRecommendationLoading(after: error),
              backgroundRecommendationRetryCount < backgroundRecommendationRetryDelays.count else {
            return false
        }

        let delay = backgroundRecommendationRetryDelays[backgroundRecommendationRetryCount]
        backgroundRecommendationRetryCount += 1

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled,
                  let self,
                  self.activeRecommendationLoadID == loadID else {
                return
            }

            await self.loadRecommendations(isBackgroundRetry: true)
        }

        return true
    }

    private func shouldRetryRecommendationLoading(after error: Error) -> Bool {
        guard let recommendationError = error as? AppleMusicRecommendationError else {
            return true
        }

        switch recommendationError {
        case .notAuthorized, .subscriptionUnavailable:
            return false
        case .catalogUnavailable, .noPlayableTracks:
            return true
        }
    }

    private func shouldPresentRecommendationError(for error: Error) -> Bool {
        guard let recommendationError = error as? AppleMusicRecommendationError else {
            return true
        }

        switch recommendationError {
        case .notAuthorized, .subscriptionUnavailable:
            return false
        case .catalogUnavailable, .noPlayableTracks:
            return true
        }
    }

    func artworkURL(for recommendedPlaylist: Playlist) -> String? {
        recommendationArtworkURLsByPlaylistID["\(recommendedPlaylist.id)"]
            ?? recommendedPlaylist.artwork?.url(width: 900, height: 900)?.absoluteString
    }
}
