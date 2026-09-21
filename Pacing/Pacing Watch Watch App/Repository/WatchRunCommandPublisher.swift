import Foundation
import WatchConnectivity

final class WatchRunCommandPublisher: NSObject {
    static let shared = WatchRunCommandPublisher()
    private let session = WCSession.default

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func send(_ command: PhoneRunCommand) {
        guard let data = try? JSONEncoder().encode(command),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if session.isReachable {
            session.sendMessage(["phoneRunCommand": payload], replyHandler: nil)
        } else {
            session.transferUserInfo(["phoneRunCommand": payload])
        }
    }
}

extension WatchRunCommandPublisher: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
