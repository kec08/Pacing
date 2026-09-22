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
    private let session = WCSession.default
    private var latestSnapshot: PhoneRunSnapshot?
    private var latestMusicSnapshot: WatchMusicPlaybackSnapshot?

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
                      (snapshot.updatedAt ?? 0) >= (self.latestMusicSnapshot?.updatedAt ?? 0)
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
