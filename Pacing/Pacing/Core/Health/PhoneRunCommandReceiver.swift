import Foundation
import WatchConnectivity

final class PhoneRunCommandReceiver: NSObject {
    static let shared = PhoneRunCommandReceiver()

    var onCommand: ((PhoneRunCommand) -> Void)?

    private let session = WCSession.default
    private var handledCommandIDs = Set<UUID>()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    private func consume(_ container: [String: Any]) {
        guard let payload = container["phoneRunCommand"] as? [String: Any],
              JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let command = try? JSONDecoder().decode(PhoneRunCommand.self, from: data)
        else { return }

        guard handledCommandIDs.insert(command.id).inserted else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onCommand?(command)
        }
    }
}

extension PhoneRunCommandReceiver: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { consume(message) }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { consume(applicationContext) }
}
