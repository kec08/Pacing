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
        participants: []
    )
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
