import Foundation
import Combine

@MainActor
final class FriendProfileViewModel: ObservableObject {
    @Published var friend: FriendUser
    @Published var stats: FriendProfileStats = .empty
    @Published var recentSongs: [FriendRecentSong] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service = FirestoreService.shared

    init(friend: FriendUser) {
        self.friend = friend
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let profileTask = service.fetchFriendUserProfile(uid: friend.id, source: .friend)
            async let statsTask = service.fetchFriendProfileStats(uid: friend.id)
            async let songsTask = service.fetchRecentSongs(uid: friend.id, limit: 10)

            friend = try await profileTask
            stats = try await statsTask
            recentSongs = try await songsTask
        } catch {
            errorMessage = "친구 프로필을 불러오지 못했어요."
        }

        isLoading = false
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
}
