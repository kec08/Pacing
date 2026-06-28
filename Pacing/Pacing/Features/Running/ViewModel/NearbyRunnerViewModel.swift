import SwiftUI
import Combine
import CoreLocation

enum RunnerFilter: String, CaseIterable {
    case friends = "친구"
    case nearby = "가까운 러너"
}

struct NearbyRunner: Identifiable {
    let id: String
    let nickname: String
    let coordinate: CLLocationCoordinate2D
    let songTitle: String
    let artist: String
    let distance: Double    // 미터
    var isMe: Bool = false
}

@MainActor
final class NearbyRunnerViewModel: ObservableObject {
    @Published var nearbyRunners: [NearbyRunner] = []
    @Published var selectedFilter: RunnerFilter = .nearby
    @Published var isObserving: Bool = false

    private let radiusMeters: Double = 1000
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

    func changeFilter(_ filter: RunnerFilter) {
        selectedFilter = filter
        filterRunners()
    }

    private func filterRunners() {
        guard let myLoc = myLocation else {
            nearbyRunners = []
            return
        }
        let myPoint = CLLocation(latitude: myLoc.latitude, longitude: myLoc.longitude)

        nearbyRunners = allRunners
            .compactMap { runner in
                let isMe = runner.id == myUID
                let point = CLLocation(latitude: runner.coordinate.latitude, longitude: runner.coordinate.longitude)
                let dist = isMe ? 0 : myPoint.distance(from: point)
                guard isMe || dist <= radiusMeters else { return nil }
                return NearbyRunner(
                    id: runner.id,
                    nickname: isMe ? "나" : runner.nickname,
                    coordinate: runner.coordinate,
                    songTitle: runner.songTitle,
                    artist: runner.artist,
                    distance: dist,
                    isMe: isMe
                )
            }
            .sorted { $0.distance < $1.distance }
    }

    func formattedDistance(_ runner: NearbyRunner) -> String {
        if runner.isMe { return "나의 위치" }
        if runner.distance < 1000 {
            return "\(Int(runner.distance))m 떨어져 있어요"
        } else {
            return String(format: "%.1fkm 떨어져 있어요", runner.distance / 1000)
        }
    }
}
