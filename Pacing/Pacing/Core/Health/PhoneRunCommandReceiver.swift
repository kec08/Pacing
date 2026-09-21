import Foundation

final class PhoneRunCommandReceiver {
    static let shared = PhoneRunCommandReceiver()

    var onCommand: ((PhoneRunCommand) -> Void)?

    private var handledCommandIDs = Set<UUID>()

    private init() {}

    func consume(_ container: [String: Any]) {
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
