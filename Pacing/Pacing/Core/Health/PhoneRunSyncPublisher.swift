import Foundation
import WatchConnectivity

final class PhoneRunSyncPublisher: NSObject {
    static let shared = PhoneRunSyncPublisher()
    private let session = WCSession.default

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func publish(_ snapshot: PhoneRunSnapshot, persist: Bool) {
        guard let data = try? JSONEncoder().encode(snapshot),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        if persist { try? session.updateApplicationContext(["phoneRun": payload]) }
        if session.isReachable { session.sendMessage(["phoneRun": payload], replyHandler: nil) }
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

extension PhoneRunSyncPublisher: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        PhoneRunCommandReceiver.shared.consume(message)
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        PhoneRunCommandReceiver.shared.consume(applicationContext)
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        PhoneRunCommandReceiver.shared.consume(userInfo)
    }
}
