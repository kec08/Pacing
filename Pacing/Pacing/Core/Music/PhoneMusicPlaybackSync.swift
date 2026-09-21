import Foundation

struct PhoneMusicTrack: Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: String?
}

struct PhoneMusicPlaybackSnapshot: Codable, Equatable {
    let title: String
    let artist: String
    let artworkURL: String?
    let isPlaying: Bool
    let recentlyPlayed: [PhoneMusicTrack]
}

enum PhoneMusicPlaybackCommand: String, Codable {
    case togglePlayback
    case previous
    case next
    case play
}

final class PhoneMusicCommandReceiver {
    static let shared = PhoneMusicCommandReceiver()
    var onCommand: ((PhoneMusicPlaybackCommand, String?) -> Void)?

    func consume(_ container: [String: Any]) {
        guard let payload = container["watchMusicCommand"] as? [String: Any],
              let action = payload["action"] as? String,
              let command = PhoneMusicPlaybackCommand(rawValue: action)
        else { return }
        let songID = payload["songID"] as? String
        DispatchQueue.main.async { [weak self] in self?.onCommand?(command, songID) }
    }
}
