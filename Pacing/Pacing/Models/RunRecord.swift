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

struct WeeklyStats {
    var totalDistance: Double  // km
    var totalDuration: Int     // 초
    var avgPace: Double        // 분/km

    var isEmpty: Bool { totalDistance == 0 }
}

struct ListenSession: Identifiable {
    let id: String
    let partnerNickname: String
    let songTitle: String
    let date: Date
}
