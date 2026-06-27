import SwiftUI
import CoreLocation

enum SearchRadius: Int, CaseIterable {
    case small = 300
    case medium = 500
    case large = 1000

    var label: String {
        switch self {
        case .small:  return "300m"
        case .medium: return "500m"
        case .large:  return "1km"
        }
    }
}

struct NearbyRunner: Identifiable {
    let id: String
    let nickname: String
    let coordinate: CLLocationCoordinate2D
    let songTitle: String
    let artist: String
    let distance: Double    // 미터
}

@MainActor
final class NearbyRunnerViewModel: ObservableObject {
    @Published var nearbyRunners: [NearbyRunner] = []
    @Published var selectedRadius: SearchRadius = .medium
    @Published var isObserving: Bool = false

    private var myUID: String = ""
    private var allRunners: [ActiveRunner] = []
    private var myLocation: CLLocationCoordinate2D?

    func startObserving(uid: String) {
        myUID = uid
        isObserving = true
        RealtimeDBService.shared.observeActiveRunners { [weak self] runners in
            Task { @MainActor [weak self] in
                self?.allRunners = runners
                self?.filterRunners()
            }
        }
    }

    func stopObserving() {
        RealtimeDBService.shared.stopObserving()
        isObserving = false
        nearbyRunners = []
    }

    func updateMyLocation(_ coord: CLLocationCoordinate2D) {
        myLocation = coord
        filterRunners()
    }

    func changeRadius(_ radius: SearchRadius) {
        selectedRadius = radius
        filterRunners()
    }

    private func filterRunners() {
        guard let myLoc = myLocation else {
            nearbyRunners = []
            return
        }
        let myPoint = CLLocation(latitude: myLoc.latitude, longitude: myLoc.longitude)
        let radiusMeters = Double(selectedRadius.rawValue)

        nearbyRunners = allRunners
            .filter { $0.id != myUID }
            .compactMap { runner in
                let point = CLLocation(latitude: runner.coordinate.latitude, longitude: runner.coordinate.longitude)
                let dist = myPoint.distance(from: point)
                guard dist <= radiusMeters else { return nil }
                return NearbyRunner(
                    id: runner.id,
                    nickname: runner.nickname,
                    coordinate: runner.coordinate,
                    songTitle: runner.songTitle,
                    artist: runner.artist,
                    distance: dist
                )
            }
            .sorted { $0.distance < $1.distance }
    }

    func formattedDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m 떨어져 있어요"
        } else {
            return String(format: "%.1fkm 떨어져 있어요", meters / 1000)
        }
    }
}
