import Foundation

struct PhoneRunSnapshot: Codable {
    enum State: String, Codable { case running, paused, ended }
    let state: State
    let elapsedSeconds: Int
    let distanceKilometers: Double
    let paceMinutesPerKilometer: Double
    let sentAt: Date
}

struct PhoneRunHistorySnapshot: Codable, Equatable {
    let monthDistanceKilometers: Double
    let monthRunCount: Int
    let recentRuns: [PhoneRunHistoryItem]
    let updatedAt: Date

    static let empty = PhoneRunHistorySnapshot(
        monthDistanceKilometers: 0,
        monthRunCount: 0,
        recentRuns: [],
        updatedAt: .distantPast
    )
}

struct WatchListenTogetherParticipant: Codable, Equatable, Identifiable {
    let id: String
    let nickname: String
    let role: String
    let profileImageData: Data?
}

struct WatchListenTogetherSnapshot: Codable, Equatable {
    let updatedAt: TimeInterval
    let isActive: Bool
    let sessionID: String?
    let title: String
    let artist: String
    let artworkURL: String?
    let artworkData: Data?
    let startedAt: Date?
    let isCurrentUserHost: Bool?
    let participants: [WatchListenTogetherParticipant]

    static let inactive = Self(
        updatedAt: 0,
        isActive: false,
        sessionID: nil,
        title: "",
        artist: "",
        artworkURL: nil,
        artworkData: nil,
        startedAt: nil,
        isCurrentUserHost: nil,
        participants: []
    )

    /// 재생 제어가 없는 게스트는 러닝 중에도 상태 전용 같이 듣기 탭을 표시합니다.
    var isCurrentUserGuest: Bool {
        isActive && isCurrentUserHost == false
    }
}

enum WatchListenTogetherElapsedTimeFormatter {
    static func text(startedAt: Date?, now: Date) -> String {
        guard let startedAt else { return "함께 듣는 중" }

        let seconds = max(0, Int(now.timeIntervalSince(startedAt)))
        if seconds < 60 { return "\(seconds)초 함께 들음" }
        return "\(seconds / 60)분 함께 들음"
    }
}

struct PhoneRunHistoryItem: Codable, Equatable, Identifiable {
    let id: String
    let startedAt: Date
    let durationSeconds: Int
    let distanceKilometers: Double
    let averagePaceMinutesPerKilometer: Double
    let elevationGainMeters: Double?
    let averageHeartRate: Double?
    let averageCadence: Double?
    let calories: Int?
    let routePoints: [PhoneRunHistoryRoutePoint]
}

struct PhoneRunHistoryRoutePoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}
