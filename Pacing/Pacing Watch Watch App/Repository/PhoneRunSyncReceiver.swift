import Foundation
import WatchConnectivity

final class PhoneRunSyncReceiver: NSObject {
    static let shared = PhoneRunSyncReceiver()
    var onSnapshot: ((PhoneRunSnapshot) -> Void)? {
        didSet {
            if let latestSnapshot { onSnapshot?(latestSnapshot) }
        }
    }
    var onCommand: ((PhoneRunCommand) -> Void)?
    var onMusicSnapshot: ((WatchMusicPlaybackSnapshot) -> Void)? {
        didSet {
            if let latestMusicSnapshot { onMusicSnapshot?(latestMusicSnapshot) }
        }
    }
    var onRunHistorySnapshot: ((PhoneRunHistorySnapshot) -> Void)? {
        didSet {
            if let latestRunHistorySnapshot { onRunHistorySnapshot?(latestRunHistorySnapshot) }
        }
    }
    var onListenTogetherSnapshot: ((WatchListenTogetherSnapshot) -> Void)? {
        didSet {
            if let latestListenTogetherSnapshot { onListenTogetherSnapshot?(latestListenTogetherSnapshot) }
        }
    }
    private let session = WCSession.default
    private var latestSnapshot: PhoneRunSnapshot?
    private var latestMusicSnapshot: WatchMusicPlaybackSnapshot?
    private var latestRunHistorySnapshot: PhoneRunHistorySnapshot?
    private var latestListenTogetherSnapshot: WatchListenTogetherSnapshot?

    private override init() {
        super.init()
        latestMusicSnapshot = WatchContentSnapshotCache.load(WatchMusicPlaybackSnapshot.self, forKey: .music)
        latestRunHistorySnapshot = WatchContentSnapshotCache.load(PhoneRunHistorySnapshot.self, forKey: .runHistory)
        latestListenTogetherSnapshot = WatchContentSnapshotCache.load(WatchListenTogetherSnapshot.self, forKey: .listenTogether)
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    /// 워치가 이미 보관한 콘텐츠를 우선 표시한 뒤 최신 iPhone 데이터로 갱신하도록 요청한다.
    func requestContentRefresh() {
        let request = ["watchRunHistoryRefresh": true]
        if session.isReachable {
            session.sendMessage(request, replyHandler: nil)
        } else {
            session.transferUserInfo(request)
        }
    }

    private func consume(_ container: [String: Any], acceptsRunSnapshot: Bool) {
        if let payload = container["phoneMusic"] as? [String: Any],
           JSONSerialization.isValidJSONObject(payload),
           let data = try? JSONSerialization.data(withJSONObject: payload),
           let snapshot = try? JSONDecoder().decode(WatchMusicPlaybackSnapshot.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      // application context와 실시간 메시지가 같은 상태를 서로
                      // 다른 순서로 전달할 수 있다. 동시각 상태는 이미 적용한
                      // 값이므로 다시 적용하지 않아 낙관적 UI가 되돌아가지 않게 한다.
                      (snapshot.updatedAt ?? 0) > (self.latestMusicSnapshot?.updatedAt ?? -.infinity)
                else { return }
                self.latestMusicSnapshot = snapshot
                WatchContentSnapshotCache.save(snapshot, forKey: .music)
                self.onMusicSnapshot?(snapshot)
            }
        }
        if let payload = container["phoneRunCommand"] as? [String: Any],
           JSONSerialization.isValidJSONObject(payload),
           let data = try? JSONSerialization.data(withJSONObject: payload),
           let command = try? JSONDecoder().decode(PhoneRunCommand.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                self?.onCommand?(command)
            }
        }

        if let payload = container["phoneRunHistory"] as? [String: Any],
           JSONSerialization.isValidJSONObject(payload),
           let data = try? JSONSerialization.data(withJSONObject: payload),
           let snapshot = try? JSONDecoder().decode(PhoneRunHistorySnapshot.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      snapshot.updatedAt > (self.latestRunHistorySnapshot?.updatedAt ?? .distantPast)
                else { return }
                self.latestRunHistorySnapshot = snapshot
                WatchContentSnapshotCache.save(snapshot, forKey: .runHistory)
                self.onRunHistorySnapshot?(snapshot)
            }
        }

        if let payload = container["phoneListenTogether"] as? [String: Any],
           JSONSerialization.isValidJSONObject(payload),
           let data = try? JSONSerialization.data(withJSONObject: payload),
           let snapshot = try? JSONDecoder().decode(WatchListenTogetherSnapshot.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      snapshot.updatedAt > (self.latestListenTogetherSnapshot?.updatedAt ?? -.infinity)
                else { return }
                self.latestListenTogetherSnapshot = snapshot
                // 종료 상태도 저장해 앱을 다시 열었을 때 과거 활성 세션이 다시 나타나지 않게 한다.
                WatchContentSnapshotCache.save(snapshot, forKey: .listenTogether)
                self.onListenTogetherSnapshot?(snapshot)
            }
        }

        // applicationContext는 마지막 운동 상태를 장시간 유지한다. 콘텐츠와 달리
        // 운동 상태를 복원하면 종료된 러닝의 정지 화면이 새 워치 실행에도 나타난다.
        guard acceptsRunSnapshot else { return }
        guard let payload = container["phoneRun"] as? [String: Any],
              JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let snapshot = try? JSONDecoder().decode(PhoneRunSnapshot.self, from: data)
        else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  (self.latestSnapshot?.sentAt ?? .distantPast) < snapshot.sentAt
            else { return }
            self.latestSnapshot = snapshot
            self.onSnapshot?(snapshot)
        }
    }
}

extension PhoneRunSyncReceiver: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        consume(session.applicationContext, acceptsRunSnapshot: false)
        requestContentRefresh()
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        consume(applicationContext, acceptsRunSnapshot: false)
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        consume(message, acceptsRunSnapshot: true)
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        consume(userInfo, acceptsRunSnapshot: true)
    }
}

private enum WatchContentSnapshotCache {
    enum Key: String {
        case music = "watch.cachedPhoneMusicSnapshot"
        case runHistory = "watch.cachedPhoneRunHistorySnapshot"
        case listenTogether = "watch.cachedPhoneListenTogetherSnapshot"
    }

    static func load<Snapshot: Decodable>(_ type: Snapshot.Type, forKey key: Key) -> Snapshot? {
        guard let data = UserDefaults.standard.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    static func save<Snapshot: Encodable>(_ snapshot: Snapshot, forKey key: Key) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key.rawValue)
    }
}
