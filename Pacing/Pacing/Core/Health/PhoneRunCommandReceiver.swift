import Foundation

final class PhoneRunCommandReceiver {
    static let shared = PhoneRunCommandReceiver()

    var onCommand: ((PhoneRunCommand) -> Void)?
    var onWatchMetrics: ((WatchRunMetricsSnapshot) -> Void)? {
        didSet {
            if let latestWatchMetrics { onWatchMetrics?(latestWatchMetrics) }
        }
    }
    private var handledCommandIDs = Set<UUID>()
    private var latestWatchMetrics: WatchRunMetricsSnapshot?

    private init() {}

    func consume(_ container: [String: Any]) {
        if let payload = container["watchRunMetrics"] as? [String: Any],
           JSONSerialization.isValidJSONObject(payload),
           let data = try? JSONSerialization.data(withJSONObject: payload),
           let snapshot = try? JSONDecoder().decode(WatchRunMetricsSnapshot.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      (self.latestWatchMetrics?.sentAt ?? .distantPast) < snapshot.sentAt
                else { return }
                self.latestWatchMetrics = snapshot
                self.onWatchMetrics?(snapshot)
            }
        }

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
