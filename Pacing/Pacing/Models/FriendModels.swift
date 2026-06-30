import Foundation

struct FriendUser: Identifiable, Equatable {
    let id: String
    let nickname: String
    let profileImageBase64: String?
    let statusText: String
    let source: FriendRecommendationSource

    var initials: String {
        String(nickname.prefix(1)).isEmpty ? "러" : String(nickname.prefix(1))
    }
}

enum FriendRecommendationSource: String, Equatable {
    case friend = "친구"
    case search = "검색"
    case nearby = "가까운 러너"
    case recent = "추천"
    case request = "요청"
}

struct FriendRequest: Identifiable, Equatable {
    let id: String
    let fromUID: String
    let toUID: String
    let status: FriendRequestStatus
    let createdAt: Date?
    let sender: FriendUser
}

enum FriendRequestStatus: String {
    case pending
    case accepted
    case rejected
}

struct FriendProfileStats: Equatable {
    let averagePace: Double
    let totalDuration: Int
    let totalDistance: Double

    static let empty = FriendProfileStats(
        averagePace: 0,
        totalDuration: 0,
        totalDistance: 0
    )
}

struct FriendRecentSong: Identifiable, Equatable {
    let id: String
    let title: String
    let artistName: String
    let playedAt: Date?
    let songStoreID: String?
}
