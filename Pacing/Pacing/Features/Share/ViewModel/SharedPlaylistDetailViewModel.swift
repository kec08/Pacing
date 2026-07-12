import Foundation
import Combine
import FirebaseAuth
import MusicKit

@MainActor
final class SharedPlaylistDetailViewModel: ObservableObject {
    enum Source {
        case shared(SharedPlaylistSummary)
        case recommendation(Playlist)
    }

    @Published private(set) var summary: SharedPlaylistSummary
    @Published var tracks: [SharedPlaylistTrack]
    @Published var isLoading: Bool = false
    @Published var isPlaying: Bool = false
    @Published var appSaveState: SharedPlaylistSaveState = .idle
    @Published var didSaveToAppleMusic: Bool = false
    @Published var canSaveToAppleMusic: Bool = false
    @Published var errorMessage: String?

    private let source: Source
    private let firestoreService = FirestoreService.shared
    private let musicService = AppleMusicRecommendationService.shared
    private var recommendationPlaylist: Playlist?

    init(sharedPlaylist: SharedPlaylistSummary) {
        self.source = .shared(sharedPlaylist)
        self.summary = sharedPlaylist
        self.tracks = sharedPlaylist.tracks
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
            }
        } catch {
            errorMessage = "플레이리스트 정보를 불러오지 못했어요."
        }
    }

    func playAll() async {
        isPlaying = true
        defer { isPlaying = false }

        do {
            switch source {
            case .shared:
                try await musicService.playTracks(with: tracks.compactMap(\.songStoreID))
            case .recommendation(let playlist):
                try await musicService.play(playlist: playlist)
            }
        } catch {
            errorMessage = "재생을 시작하지 못했어요."
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
        guard case let .recommendation(playlist) = source else { return }

        do {
            try await musicService.addToLibrary(playlist: playlist)
            didSaveToAppleMusic = true
        } catch {
            errorMessage = "Apple Music에 저장하지 못했어요."
        }
    }

    var primarySaveTitle: String {
        switch source {
        case .shared:
            return appSaveState == .saved ? "저장됨" : "플레이리스트 저장"
        case .recommendation:
            return didSaveToAppleMusic ? "Apple Music에 저장됨" : "Apple Music에 저장"
        }
    }

    var isSaveButtonDisabled: Bool {
        switch source {
        case .shared:
            return appSaveState == .saving || appSaveState == .saved
        case .recommendation:
            return !canSaveToAppleMusic || didSaveToAppleMusic
        }
    }

    var ownerDescription: String {
        summary.ownerNickname
    }

    var updatedDescription: String {
        guard let updatedAt = summary.updatedAt else { return "업데이트 정보 없음" }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
}
