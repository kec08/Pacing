import Foundation
import CoreLocation

struct RunLapPace: Identifiable, Equatable {
    let kilometer: Int
    let pace: Double

    var id: Int { kilometer }
}

struct RunRecord: Identifiable {
    let id: String
    let startedAt: Date
    let duration: Int          // 초
    let distance: Double       // km
    let avgPace: Double        // 분/km
    let routeCoordinates: [CLLocationCoordinate2D]
    let lapPaces: [RunLapPace]
    let elevationGainMeters: Double?
    let averageHeartRate: Double?
    let averageCadence: Double?

    init(
        id: String,
        startedAt: Date,
        duration: Int,
        distance: Double,
        avgPace: Double,
        routeCoordinates: [CLLocationCoordinate2D],
        lapPaces: [RunLapPace],
        elevationGainMeters: Double? = nil,
        averageHeartRate: Double? = nil,
        averageCadence: Double? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.distance = distance
        self.avgPace = avgPace
        self.routeCoordinates = routeCoordinates
        self.lapPaces = lapPaces
        self.elevationGainMeters = elevationGainMeters
        self.averageHeartRate = averageHeartRate
        self.averageCadence = averageCadence
    }
}

extension RunRecord {
    static let minimumValidDistance: Double = 0.10
    static let maximumValidPace: Double = 30.0

    var isPaceValid: Bool {
        distance.isFinite && duration > 0 && avgPace.isFinite
            && distance >= Self.minimumValidDistance
            && avgPace > 0
            && avgPace <= Self.maximumValidPace
    }

    var displayPace: Double { isPaceValid ? avgPace : 0 }

    static func formattedPace(_ pace: Double) -> String {
        guard pace.isFinite, pace > 0, pace <= maximumValidPace else { return "--'--\"" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    static let dummies: [RunRecord] = {
        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now)! }
        return [
            RunRecord(id: "1", startedAt: daysAgo(1), duration: 1911, distance: 5.23, avgPace: 6.1, routeCoordinates: [], lapPaces: []),
            RunRecord(id: "2", startedAt: daysAgo(4), duration: 1509, distance: 3.87, avgPace: 6.5, routeCoordinates: [], lapPaces: []),
            RunRecord(id: "3", startedAt: daysAgo(8), duration: 2833, distance: 8.02, avgPace: 5.9, routeCoordinates: [], lapPaces: []),
            RunRecord(id: "4", startedAt: daysAgo(15), duration: 1498, distance: 4.21, avgPace: 5.917, routeCoordinates: [], lapPaces: []),
            RunRecord(id: "5", startedAt: daysAgo(22), duration: 3750, distance: 10.0, avgPace: 6.25, routeCoordinates: [], lapPaces: []),
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
    var hostProfileImageBase64: String = ""
    let guestUID: String
    let guestNickname: String
    var guestProfileImageBase64: String = ""
    var songStoreID: String
    var songTitle: String
    var artistName: String
    var artworkURL: String
    var artworkData: String
    /// 호스트가 곡을 전환할 때만 변경되는 식별자입니다.
    /// 위치 보정 업데이트와 실제 곡 전환을 구분해 게스트의 중복 큐 준비를 방지합니다.
    var playbackEventID: String = ""
    var playbackPosition: Double
    var serverTimestamp: Double
    var status: String          // pending / active / ended / rejected
    var isPlaying: Bool

    var date: Date { Date(timeIntervalSince1970: serverTimestamp / 1000.0) }

    func partnerNickname(for currentUID: String) -> String {
        currentUID == hostUID ? guestNickname : hostNickname
    }

    func partnerUID(for currentUID: String) -> String {
        currentUID == hostUID ? guestUID : hostUID
    }

    func profileImageBase64(for uid: String) -> String {
        uid == hostUID ? hostProfileImageBase64 : guestProfileImageBase64
    }
}
