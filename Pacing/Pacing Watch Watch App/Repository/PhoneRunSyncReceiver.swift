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
    private let session = WCSession.default
    private var latestSnapshot: PhoneRunSnapshot?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    private func consume(_ container: [String: Any]) {
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
            self?.latestSnapshot = snapshot
            self?.onSnapshot?(snapshot)
        }
    }
}

extension PhoneRunSyncReceiver: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        consume(session.applicationContext)
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { consume(applicationContext) }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { consume(message) }
}
