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
    @Published private(set) var loadError: String?

    private let radiusMeters: Double = 1000
    private var myUID: String = ""
    private var allRunners: [ActiveRunner] = []
    private var friendIDs: Set<String> = []
    private var friendProfileImages: [String: String] = [:]
    private var loadedProfileImageIDs: Set<String> = []
    private var myLocation: CLLocationCoordinate2D?

    func startObserving(uid: String) {
        myUID = uid
        isObserving = true
        loadError = nil
        Task { await loadFriendIDs(uid: uid) }
        RealtimeDBService.shared.observeActiveRunners { [weak self] runners in
            Task { @MainActor [weak self] in
                self?.allRunners = runners
                self?.filterRunners()
                await self?.loadProfileImages(for: self?.profileImageCandidateIDs() ?? [])
            }
        } onError: { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadError = "주변 러너 정보를 불러오지 못했어요. 네트워크 연결을 확인해 주세요."
            }
        }
    }

    func stopObserving() {
        RealtimeDBService.shared.stopObserving()
        isObserving = false
        nearbyRunners = []
        activeFriendRunners = []
        loadedProfileImageIDs = []
        friendProfileImages = [:]
        loadError = nil
    }

    func updateMyLocation(_ coord: CLLocationCoordinate2D) {
        myLocation = coord
        filterRunners()
        Task { await loadProfileImages(for: profileImageCandidateIDs()) }
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
                    profileImageBase64: friendProfileImages[runner.id],
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
            await loadProfileImages(for: profileImageCandidateIDs())
        } catch {
            friendIDs = []
            friendProfileImages = [:]
            loadError = "친구 위치를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
            filterRunners()
        }
    }

    private func loadProfileImages(for runnerIDs: [String]) async {
        let idsToLoad = Set(runnerIDs).subtracting(loadedProfileImageIDs)
        guard !idsToLoad.isEmpty else { return }

        await withTaskGroup(of: (String, String?, Bool).self) { group in
            for id in idsToLoad {
                group.addTask {
                    do {
                        let profile = try await FirestoreService.shared.fetchUserProfile(uid: id)
                        return (id, profile["profileImageBase64"] as? String, true)
                    } catch {
                        return (id, nil, false)
                    }
                }
            }

            for await (id, image, succeeded) in group {
                guard succeeded else { continue }
                loadedProfileImageIDs.insert(id)
                if let image, !image.isEmpty {
                    friendProfileImages[id] = image
                }
            }
        }
        filterRunners()
    }

    private func profileImageCandidateIDs() -> [String] {
        guard let myLocation else { return [] }
        let myPoint = CLLocation(latitude: myLocation.latitude, longitude: myLocation.longitude)

        return allRunners.compactMap { runner in
            let point = CLLocation(
                latitude: runner.coordinate.latitude,
                longitude: runner.coordinate.longitude
            )
            let isNearby = myPoint.distance(from: point) <= radiusMeters
            return isNearby || friendIDs.contains(runner.id) ? runner.id : nil
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
