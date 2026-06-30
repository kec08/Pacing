import Foundation
import Combine
import FirebaseAuth

@MainActor
final class FriendProfileViewModel: ObservableObject {
    @Published var friend: FriendUser
    @Published var relationship: FriendRelationship
    @Published var stats: FriendProfileStats = .empty
    @Published var recentSongs: [FriendRecentSong] = []
    @Published var isLoading: Bool = false
    @Published var isUpdatingRelationship: Bool = false
    @Published var errorMessage: String?

    private let service = FirestoreService.shared

    init(friend: FriendUser, initialRelationship: FriendRelationship) {
        self.friend = friend
        self.relationship = initialRelationship
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let profileTask = service.fetchFriendUserProfile(uid: friend.id, source: .friend)
            async let statsTask = service.fetchFriendProfileStats(uid: friend.id)
            async let songsTask = service.fetchRecentSongs(uid: friend.id, limit: 5)
            async let relationshipTask = fetchRelationship()

            friend = try await profileTask
            stats = try await statsTask
            recentSongs = try await songsTask
            relationship = try await relationshipTask
        } catch {
            errorMessage = "친구 프로필을 불러오지 못했어요."
        }

        isLoading = false
    }

    func sendFriendRequest() async -> Bool {
        guard relationship == .none, let uid = Auth.auth().currentUser?.uid else {
            return false
        }

        isUpdatingRelationship = true
        errorMessage = nil

        do {
            try await service.sendFriendRequest(from: uid, to: friend.id)
            relationship = .requestPending
            isUpdatingRelationship = false
            return true
        } catch {
            errorMessage = "친구 요청을 보내지 못했어요."
            isUpdatingRelationship = false
            return false
        }
    }

    func cancelFriendRequest() async -> Bool {
        guard relationship == .requestPending, let uid = Auth.auth().currentUser?.uid else {
            return false
        }

        isUpdatingRelationship = true
        errorMessage = nil

        do {
            try await service.cancelSentFriendRequest(from: uid, to: friend.id)
            relationship = .none
            isUpdatingRelationship = false
            return true
        } catch {
            errorMessage = "친구 요청을 취소하지 못했어요."
            isUpdatingRelationship = false
            return false
        }
    }

    private func fetchRelationship() async throws -> FriendRelationship {
        guard let uid = Auth.auth().currentUser?.uid else {
            return relationship
        }

        return try await service.fetchFriendRelationship(currentUID: uid, targetUID: friend.id)
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

    var actionTitle: String {
        switch relationship {
        case .friend:
            return "친구"
        case .requestPending:
            return "요청 대기중"
        case .none:
            return "친구 추가"
        }
    }

    var canTapAction: Bool {
        relationship != .friend && !isUpdatingRelationship
    }
}
