import Combine
import Foundation
import WatchConnectivity

struct WatchMusicTrack: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: String?
}

struct WatchMusicPlaybackSnapshot: Codable, Equatable {
    let title: String
    let artist: String
    let artworkURL: String?
    let isPlaying: Bool
    let recentlyPlayed: [WatchMusicTrack]

    static let empty = Self(
        title: "재생 중인 음악 없음",
        artist: "iPhone에서 음악을 재생해 주세요",
        artworkURL: nil,
        isPlaying: false,
        recentlyPlayed: []
    )
}

enum WatchMusicPlaybackCommand: String, Codable {
    case togglePlayback
    case previous
    case next
    case play
}

protocol WatchMusicPlaybackRepository: AnyObject {
    var snapshot: AnyPublisher<WatchMusicPlaybackSnapshot, Never> { get }
    func refresh()
    func send(_ command: WatchMusicPlaybackCommand, songID: String?)
}

/// Watch는 재생 엔진을 직접 소유하지 않고 iPhone의 MusicKit 상태를 구독합니다.
final class PhoneMusicPlaybackRepository: NSObject, WatchMusicPlaybackRepository {
    static let shared = PhoneMusicPlaybackRepository()

    private let snapshotSubject = CurrentValueSubject<WatchMusicPlaybackSnapshot, Never>(.empty)
    private let session = WCSession.default

    var snapshot: AnyPublisher<WatchMusicPlaybackSnapshot, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }

    private override init() {
        super.init()
        PhoneRunSyncReceiver.shared.onMusicSnapshot = { [weak self] snapshot in
            self?.snapshotSubject.send(snapshot)
        }
        guard WCSession.isSupported() else { return }
        session.activate()
    }

    func refresh() {
        guard session.isReachable else { return }
        session.sendMessage(["watchMusicRefresh": true], replyHandler: nil)
    }

    func send(_ command: WatchMusicPlaybackCommand, songID: String? = nil) {
        var payload: [String: Any] = ["action": command.rawValue]
        if let songID { payload["songID"] = songID }

        if session.isReachable {
            session.sendMessage(["watchMusicCommand": payload], replyHandler: nil)
        } else {
            session.transferUserInfo(["watchMusicCommand": payload])
        }
    }
}
