import Foundation
import FirebaseDatabase
import CoreLocation

struct ActiveRunner: Identifiable {
    let id: String          // uid
    let nickname: String
    let coordinate: CLLocationCoordinate2D
    let songTitle: String
    let artist: String
    let updatedAt: TimeInterval
}

final class RealtimeDBService {
    static let shared = RealtimeDBService()
    private let db = Database.database().reference()
    private var broadcastTimer: Timer?
    private var observeHandle: DatabaseHandle?

    private init() {}

    // MARK: - 브로드캐스트 시작
    func startBroadcast(uid: String, nickname: String, locationProvider: @escaping () -> CLLocationCoordinate2D?, songProvider: @escaping () -> (title: String, artist: String)) {
        // 오프라인 시 자동 삭제
        db.child("activeRunners").child(uid).onDisconnectRemoveValue()

        broadcastTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let coord = locationProvider() else { return }
            let song = songProvider()
            self?.upload(uid: uid, nickname: nickname, coord: coord, song: song)
        }
        broadcastTimer?.fire()
    }

    private func upload(uid: String, nickname: String, coord: CLLocationCoordinate2D, song: (title: String, artist: String)) {
        let data: [String: Any] = [
            "latitude": coord.latitude,
            "longitude": coord.longitude,
            "nickname": nickname,
            "currentSongTitle": song.title,
            "currentArtist": song.artist,
            "updatedAt": ServerValue.timestamp()
        ]
        db.child("activeRunners").child(uid).setValue(data)
    }

    // MARK: - 브로드캐스트 중지
    func stopBroadcast(uid: String) {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        db.child("activeRunners").child(uid).removeValue()
    }

    // MARK: - 주변 러너 구독
    func observeActiveRunners(onChange: @escaping ([ActiveRunner]) -> Void) {
        observeHandle = db.child("activeRunners").observe(.value) { snapshot in
            var runners: [ActiveRunner] = []
            for child in snapshot.children {
                guard
                    let snap = child as? DataSnapshot,
                    let d = snap.value as? [String: Any],
                    let lat = d["latitude"] as? Double,
                    let lng = d["longitude"] as? Double
                else { continue }

                let runner = ActiveRunner(
                    id: snap.key,
                    nickname: d["nickname"] as? String ?? "러너",
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    songTitle: d["currentSongTitle"] as? String ?? "",
                    artist: d["currentArtist"] as? String ?? "",
                    updatedAt: d["updatedAt"] as? TimeInterval ?? 0
                )
                runners.append(runner)
            }
            onChange(runners)
        }
    }

    // MARK: - 구독 해제
    func stopObserving() {
        if let handle = observeHandle {
            db.child("activeRunners").removeObserver(withHandle: handle)
            observeHandle = nil
        }
    }
}
