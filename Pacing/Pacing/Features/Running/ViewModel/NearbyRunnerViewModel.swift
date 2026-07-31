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
    let profileImageBase64: String?
    let distance: Double    // 미터
    var isMe: Bool = false
}

@MainActor
final class NearbyRunnerViewModel: ObservableObject {
    @Published var nearbyRunners: [NearbyRunner] = []
    @Published private(set) var activeFriendRunners: [NearbyRunner] = []
    @Published var selectedFilter: RunnerFilter = .nearby
    @Published var isObserving: Bool = false

    private let radiusMeters: Double = 1000
    private var myUID: String = ""
    private var allRunners: [ActiveRunner] = []
    private var friendIDs: Set<String> = []
    private var friendProfileImages: [String: String] = [:]
    private var myLocation: CLLocationCoordinate2D?

    func startObserving(uid: String) {
        myUID = uid
        isObserving = true
        Task { await loadFriendIDs(uid: uid) }
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
        activeFriendRunners = []
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
            activeFriendRunners = []
            return
        }
        let myPoint = CLLocation(latitude: myLoc.latitude, longitude: myLoc.longitude)

        let activeRunners: [NearbyRunner] = allRunners
            .compactMap { runner -> NearbyRunner? in
                guard runner.id != myUID else { return nil }
                let point = CLLocation(latitude: runner.coordinate.latitude, longitude: runner.coordinate.longitude)
                let dist = myPoint.distance(from: point)
                return NearbyRunner(
                    id: runner.id,
                    nickname: runner.nickname,
                    coordinate: runner.coordinate,
                    songTitle: runner.songTitle,
                    artist: runner.artist,
                    profileImageBase64: friendProfileImages[runner.id] ?? runner.profileImageBase64,
                    distance: dist,
                    isMe: false
                )
            }

        // 지도에는 거리와 무관하게 현재 러닝 중인 친구만 표시한다.
        activeFriendRunners = activeRunners
            .filter { friendIDs.contains($0.id) }
            .sorted { $0.distance < $1.distance }

        nearbyRunners = activeRunners
            .filter { runner in
                switch selectedFilter {
                case .friends:
                    return friendIDs.contains(runner.id)
                case .nearby:
                    return runner.distance <= radiusMeters
                }
            }
            .sorted { $0.distance < $1.distance }
    }

    private func loadFriendIDs(uid: String) async {
        guard !uid.isEmpty else { return }
        do {
            let friends = try await FirestoreService.shared.fetchFriends(uid: uid)
            friendIDs = Set(friends.map(\.id))
            friendProfileImages = Dictionary(
                uniqueKeysWithValues: friends.compactMap { friend in
                    guard let image = friend.profileImageBase64, !image.isEmpty else { return nil }
                    return (friend.id, image)
                }
            )
            filterRunners()
        } catch {
            friendIDs = []
            friendProfileImages = [:]
            filterRunners()
        }
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
