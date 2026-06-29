import Foundation
import CoreLocation

struct RunRecord: Identifiable {
    let id: String
    let startedAt: Date
    let duration: Int          // 초
    let distance: Double       // km
    let avgPace: Double        // 분/km
    let routeCoordinates: [CLLocationCoordinate2D]
}

extension RunRecord {
    static let dummies: [RunRecord] = {
        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now)! }
        return [
            RunRecord(id: "1", startedAt: daysAgo(1), duration: 1911, distance: 5.23, avgPace: 6.1, routeCoordinates: []),
            RunRecord(id: "2", startedAt: daysAgo(4), duration: 1509, distance: 3.87, avgPace: 6.5, routeCoordinates: []),
            RunRecord(id: "3", startedAt: daysAgo(8), duration: 2833, distance: 8.02, avgPace: 5.9, routeCoordinates: []),
            RunRecord(id: "4", startedAt: daysAgo(15), duration: 1498, distance: 4.21, avgPace: 5.917, routeCoordinates: []),
            RunRecord(id: "5", startedAt: daysAgo(22), duration: 3750, distance: 10.0, avgPace: 6.25, routeCoordinates: []),
        ]
    }()
}

struct WeeklyStats {
    var totalDistance: Double  // km
    var totalDuration: Int     // 초
    var avgPace: Double        // 분/km

    var isEmpty: Bool { totalDistance == 0 }
}

struct ListenSession: Identifiable {
    let id: String
    let hostUID: String
    let hostNickname: String
    let guestUID: String
    let guestNickname: String
    var songStoreID: String
    var songTitle: String
    var artistName: String
    var playbackPosition: Double
    var serverTimestamp: Double
    var status: String          // pending / active / ended / rejected
    var isPlaying: Bool

    // 홈탭 최근 활동 표시용 편의 프로퍼티
    var partnerNickname: String { guestNickname }
    var date: Date { Date(timeIntervalSince1970: serverTimestamp / 1000.0) }
}
