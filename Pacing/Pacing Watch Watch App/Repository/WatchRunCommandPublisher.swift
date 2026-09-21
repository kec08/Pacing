import Foundation
import WatchConnectivity

final class WatchRunCommandPublisher {
    static let shared = WatchRunCommandPublisher()
    private let session = WCSession.default

    private init() {}

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
