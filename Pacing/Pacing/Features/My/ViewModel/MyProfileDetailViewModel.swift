import Foundation
import Combine
import FirebaseAuth

@MainActor
final class MyProfileDetailViewModel: ObservableObject {
    @Published var stats: FriendProfileStats = .empty
    @Published var recentSongs: [FriendRecentSong] = []
    @Published var recentRuns: [RunRecord] = []
    @Published var recentSongArtworkURLs: [String: String] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service = FirestoreService.shared
    private let musicService = AppleMusicRecommendationService.shared

    func load() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            stats = .empty
            recentSongs = []
            recentRuns = []
            recentSongArtworkURLs = [:]
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let statsTask = service.fetchFriendProfileStats(uid: uid)
            async let songsTask = service.fetchRecentSongs(uid: uid, limit: 5)
            async let runsTask = service.fetchRunHistory(uid: uid, limit: 5)

            stats = try await statsTask
            recentSongs = try await songsTask
            recentRuns = try await runsTask
            recentSongArtworkURLs = await resolveArtworkURLs(for: recentSongs)
        } catch {
            errorMessage = "내 프로필 정보를 불러오지 못했어요."
        }

        isLoading = false
    }

    private func resolveArtworkURLs(for songs: [FriendRecentSong]) async -> [String: String] {
        var urls: [String: String] = [:]
        for song in songs {
            if let url = await musicService.resolvedRecentSongArtworkURL(title: song.title, artistName: song.artistName) {
                urls[song.id] = url
            }
        }
        return urls
    }

    var formattedAveragePace: String {
        guard stats.averagePace > 0 else { return "--'--\"" }
        let minutes = Int(stats.averagePace)
        let seconds = Int((stats.averagePace - Double(minutes)) * 60)
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    var formattedTotalDuration: String {
        let hours = stats.totalDuration / 3600
        let minutes = (stats.totalDuration % 3600) / 60

        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }

        return "\(minutes)분"
    }

    var formattedTotalDistance: String {
        String(format: "%.1fkm", stats.totalDistance)
    }

    var activityText: String {
        FriendActivityText.runningStatus(lastRunDate: stats.lastRunDate)
    }

    var isTodayActivity: Bool {
        FriendActivityText.isTodayStatus(activityText)
    }
}
