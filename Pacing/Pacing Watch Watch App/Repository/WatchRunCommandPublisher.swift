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

    func publish(_ snapshot: WatchRunMetricsSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if session.isReachable {
            session.sendMessage(["watchRunMetrics": payload], replyHandler: nil)
        }

        if snapshot.state == .ended {
            // Keep the final HealthKit total queued if the phone is temporarily unreachable.
            session.transferUserInfo(["watchRunMetrics": payload])
        }

        // 연결이 잠시 끊긴 동안에는 모든 초당 샘플을 큐에 쌓지 않고 최신 값만 보존합니다.
        try? session.updateApplicationContext(["watchRunMetrics": payload])
    }
}
