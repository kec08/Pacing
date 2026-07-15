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

enum FriendRelationship: Equatable {
    case friend
    case requestPending
    case none
}

struct FriendProfileStats: Equatable {
    let averagePace: Double
    let totalDuration: Int
    let totalDistance: Double
    let lastRunDate: Date?

    static let empty = FriendProfileStats(
        averagePace: 0,
        totalDuration: 0,
        totalDistance: 0,
        lastRunDate: nil
    )
}

struct FriendRecentSong: Identifiable, Equatable {
    let id: String
    let title: String
    let artistName: String
    let playedAt: Date?
    let songStoreID: String?
    let artworkURL: String?
    let artworkData: String?
}

enum FriendActivityText {
    static func runningStatus(lastRunDate: Date?) -> String {
        guard let lastRunDate else {
            return "러닝 기록 없음"
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(lastRunDate) {
            return "오늘 러닝 완료"
        }

        if calendar.isDateInYesterday(lastRunDate) {
            return "어제 러닝 완료"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return "\(formatter.string(from: lastRunDate)) 러닝 완료"
    }

    static func isTodayStatus(_ text: String) -> Bool {
        text == "오늘 러닝 완료"
    }
}
