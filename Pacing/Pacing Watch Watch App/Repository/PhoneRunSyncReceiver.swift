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
    private let session = WCSession.default
    private var latestSnapshot: PhoneRunSnapshot?
    private var latestMusicSnapshot: WatchMusicPlaybackSnapshot?
    private var latestRunHistorySnapshot: PhoneRunHistorySnapshot?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    private func consume(_ container: [String: Any]) {
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
                self.onRunHistorySnapshot?(snapshot)
            }
        }

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
        consume(session.applicationContext)
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { consume(applicationContext) }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { consume(message) }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) { consume(userInfo) }
}
