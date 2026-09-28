import Foundation

struct PhoneRunSnapshot: Codable {
    enum State: String, Codable { case running, paused, ended }

    let state: State
    let elapsedSeconds: Int
    let distanceKilometers: Double
    let paceMinutesPerKilometer: Double
    let sentAt: Date
}

/// Watch 활동 탭에 표시할 iPhone 러닝 기록의 경량 동기화 모델입니다.
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

struct PhoneRunHistoryItem: Codable, Equatable, Identifiable {
    let id: String
    let startedAt: Date
    let durationSeconds: Int
    let distanceKilometers: Double
    let averagePaceMinutesPerKilometer: Double
    let elevationGainMeters: Double?
    let averageHeartRate: Double?
    let averageCadence: Double?
}
