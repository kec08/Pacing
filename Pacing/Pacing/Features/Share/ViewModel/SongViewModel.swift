import Combine
import FirebaseAuth
import Foundation
import MusicKit

@MainActor
final class SongViewModel: ObservableObject {
    @Published var friendSharedPlaylists: [SharedPlaylistSummary] = []
    @Published var recentlyPlayedAlbums: [Album] = []
    @Published var recommendedPlaylists: [Playlist] = []
    @Published var recommendationArtworkURLs: [String: String] = [:]
    @Published var genreAlbumRows: [GenreAlbumRow] = []
    @Published var moodPlaylists: [MoodPlaylistShelfItem] = []
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
    private var activeFriendLoadID: UUID?
    private var friendArtworkEnrichmentTask: Task<Void, Never>?
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

        let loadID = UUID()
        activeFriendLoadID = loadID
        friendArtworkEnrichmentTask?.cancel()
        isLoadingFriends = true
        defer { isLoadingFriends = false }

        do {
            let fetchedPlaylists = try await firestoreService.fetchFriendSharedPlaylists(currentUID: uid)
            guard activeFriendLoadID == loadID else { return }

            // Firestore 결과를 먼저 노출한다. 대표 커버 보강은 목록 최초 표시를
            // 막지 않는 후속 작업으로 처리한다.
            friendSharedPlaylists = fetchedPlaylists

            let artworkURLs = friendSharedPlaylists.compactMap(\.effectiveArtworkURL)
            Task {
                await ArtworkImageStore.shared.prefetch(urlStrings: artworkURLs)
            }

            friendArtworkEnrichmentTask = Task { [weak self] in
                guard let self else { return }
                let enrichedPlaylists = await self.enrichFirstTrackArtwork(for: fetchedPlaylists)
                guard !Task.isCancelled, self.activeFriendLoadID == loadID else { return }
                self.friendSharedPlaylists = enrichedPlaylists
            }
        } catch {
            guard activeFriendLoadID == loadID else { return }
            friendSharedPlaylists = []
            if showError {
                errorMessage = "친구 플레이리스트를 불러오지 못했어요."
            }
        }
    }

    private func enrichFirstTrackArtwork(
        for playlists: [SharedPlaylistSummary]
    ) async -> [SharedPlaylistSummary] {
        await withTaskGroup(of: (Int, SharedPlaylistSummary).self) { group in
            for (index, playlist) in playlists.enumerated() {
                group.addTask { @MainActor [musicService] in
                    guard let firstTrack = playlist.tracks.first,
                          firstTrack.effectiveArtworkURL == nil
                    else {
                        return (index, playlist)
                    }

                    let enrichedFirstTrack = await musicService
                        .prepareSharedTracksForPlayback([firstTrack])
                        .first ?? firstTrack
                    let tracks = [enrichedFirstTrack] + Array(playlist.tracks.dropFirst())

                    return (
                        index,
                        SharedPlaylistSummary(
                            id: playlist.id,
                            ownerUID: playlist.ownerUID,
                            ownerNickname: playlist.ownerNickname,
                            title: playlist.title,
                            subtitle: playlist.subtitle,
                            artworkURL: playlist.artworkURL,
                            artworkData: playlist.artworkData,
                            sourcePlaylistID: playlist.sourcePlaylistID,
                            sourcePlaylistURL: playlist.sourcePlaylistURL,
                            trackCount: playlist.trackCount,
                            updatedAt: playlist.updatedAt,
                            tracks: tracks
                        )
                    )
                }
            }

            var enrichedPlaylists = playlists
            for await (index, playlist) in group {
                enrichedPlaylists[index] = playlist
            }
            return enrichedPlaylists
        }
    }

    private func loadRecommendations(isBackgroundRetry: Bool = false) async {
        guard musicAuthorizationStatus == .authorized else {
            recentlyPlayedAlbums = []
            recommendedPlaylists = []
            recommendationArtworkURLs = [:]
            genreAlbumRows = []
            moodPlaylists = []
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
            recommendationArtworkURLs = await musicService.resolvedRecommendationPlaylistArtworkURLs(
                for: result.bundle.playlists
            )
            genreAlbumRows = result.bundle.genreAlbumRows
            moodPlaylists = result.bundle.moodPlaylists

            let artworkURLs =
                result.bundle.recentlyPlayedAlbums.compactMap { $0.artwork?.url(width: 900, height: 900)?.absoluteString } +
                Array(recommendationArtworkURLs.values) +
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
            recommendationArtworkURLs = [:]
            genreAlbumRows = []
            moodPlaylists = []
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

}
