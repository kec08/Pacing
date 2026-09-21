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
    /// Watch가 iPhone과 다른 네트워크 상태여도 현재 앨범 아트를 표시하도록 축소 JPEG를 함께 전달합니다.
    let artworkData: Data?
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
    var onRefreshRequested: (() -> Void)?

    func consume(_ container: [String: Any]) {
        if container["watchMusicRefresh"] as? Bool == true {
            DispatchQueue.main.async { [weak self] in self?.onRefreshRequested?() }
            return
        }

        guard let payload = container["watchMusicCommand"] as? [String: Any],
              let action = payload["action"] as? String,
              let command = PhoneMusicPlaybackCommand(rawValue: action)
        else { return }
        let songID = payload["songID"] as? String
        DispatchQueue.main.async { [weak self] in self?.onCommand?(command, songID) }
    }
}
