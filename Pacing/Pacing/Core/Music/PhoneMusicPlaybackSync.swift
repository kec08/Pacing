import Foundation
import UIKit

struct PhoneMusicTrack: Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: String?
    let artworkData: Data?
}

struct PhoneMusicPlaybackSnapshot: Codable, Equatable {
    /// WatchConnectivity 메시지가 순서와 다르게 도착해도 최신 iPhone 상태만 적용하기 위한 시각입니다.
    let updatedAt: TimeInterval?
    let title: String
    let artist: String
    let artworkURL: String?
    /// Watch가 iPhone과 다른 네트워크 상태여도 현재 앨범 아트를 표시하도록 축소 JPEG를 함께 전달합니다.
    let artworkData: Data?
    let isPlaying: Bool
    let recentlyPlayed: [PhoneMusicTrack]
    /// iPhone에서 현재 재생 중인 플레이리스트의 전체 큐입니다.
    let playlistTracks: [PhoneMusicTrack]

    func removingRecentArtworkData() -> Self {
        Self(
            updatedAt: updatedAt,
            title: title,
            artist: artist,
            artworkURL: artworkURL,
            artworkData: artworkData,
            isPlaying: isPlaying,
            recentlyPlayed: recentlyPlayed.map {
                PhoneMusicTrack(id: $0.id, title: $0.title, artist: $0.artist, artworkURL: $0.artworkURL, artworkData: nil)
            },
            // 플레이리스트의 현재 곡 인접 아트워크는 Watch에서 즉시 보여 줄
            // 우선순위 데이터다. 최근 재생 썸네일만 먼저 제거해도 현재 목록의
            // 앨범 아트를 유지할 수 있다.
            playlistTracks: playlistTracks
        )
    }

    func removingAllArtworkData() -> Self {
        removingRecentArtworkData().withCurrentArtworkData(nil)
    }

    private func withCurrentArtworkData(_ artworkData: Data?) -> Self {
        Self(updatedAt: updatedAt, title: title, artist: artist, artworkURL: artworkURL, artworkData: artworkData, isPlaying: isPlaying, recentlyPlayed: recentlyPlayed, playlistTracks: playlistTracks)
    }
}

enum PhoneMusicPlaybackCommand: String, Codable {
    case togglePlayback
    case setPlaybackState
    case previous
    case next
    case play
}

enum WatchMusicArtworkEncoder {
    static func encodeCurrentArtwork(_ image: UIImage) -> Data? {
        encode(image, maximumPixelSize: 180, maximumByteCount: 14_000)
    }

    static func encodeRecentArtwork(_ image: UIImage) -> Data? {
        // Watch 러닝 플레이리스트 셀은 38pt다. Retina 화면의 선명도는 확보하되
        // 현재 곡 주변의 여러 커버가 전송 한도 안에 남도록 상한을 제한한다.
        encode(image, maximumPixelSize: 64, maximumByteCount: 2_200)
    }

    static func encodeProfileArtwork(_ image: UIImage) -> Data? {
        encode(image, maximumPixelSize: 56, maximumByteCount: 2_400)
    }

    private static func encode(_ image: UIImage, maximumPixelSize: CGFloat, maximumByteCount: Int) -> Data? {
        let largestDimension = max(image.size.width, image.size.height)
        let scale = min(1, maximumPixelSize / largestDimension)
        var size = CGSize(width: max(1, (image.size.width * scale).rounded()), height: max(1, (image.size.height * scale).rounded()))

        for quality in stride(from: CGFloat(0.7), through: 0.2, by: -0.1) {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let data = UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: quality) { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            if data.count <= maximumByteCount { return data }
            size = CGSize(width: max(24, (size.width * 0.8).rounded()), height: max(24, (size.height * 0.8).rounded()))
        }
        return nil
    }
}

struct PhoneListenTogetherParticipant: Codable, Equatable, Identifiable {
    let id: String
    let nickname: String
    let role: String
    let profileImageData: Data?
}

struct PhoneListenTogetherSnapshot: Codable, Equatable {
    let updatedAt: TimeInterval
    let isActive: Bool
    let sessionID: String?
    let title: String
    let artist: String
    let artworkURL: String?
    /// 앨범 아트는 Watch가 독립 네트워크에 있거나 URL이 만료된 경우에도 표시할 수 있도록 보조 데이터를 보관합니다.
    let artworkData: Data?
    let startedAt: Date?
    let participants: [PhoneListenTogetherParticipant]

    static let inactive = Self(
        updatedAt: 0,
        isActive: false,
        sessionID: nil,
        title: "",
        artist: "",
        artworkURL: nil,
        artworkData: nil,
        startedAt: nil,
        participants: []
    )

    func removingProfileImages() -> Self {
        Self(
            updatedAt: updatedAt,
            isActive: isActive,
            sessionID: sessionID,
            title: title,
            artist: artist,
            artworkURL: artworkURL,
            artworkData: artworkData,
            startedAt: startedAt,
            participants: participants.map {
                PhoneListenTogetherParticipant(id: $0.id, nickname: $0.nickname, role: $0.role, profileImageData: nil)
            }
        )
    }
}

final class PhoneMusicCommandReceiver {
    static let shared = PhoneMusicCommandReceiver()
    var onCommand: ((PhoneMusicPlaybackCommand, String?, Bool?, String?, String?) -> Void)?
    var onRefreshRequested: (() -> Void)?
    var onPlaylistArtworkRequested: (([String]) -> Void)?

    func consume(_ container: [String: Any]) {
        if container["watchMusicRefresh"] as? Bool == true {
            DispatchQueue.main.async { [weak self] in self?.onRefreshRequested?() }
            return
        }

        if let songIDs = container["watchMusicArtworkIDs"] as? [String] {
            // Watch의 LazyVStack이 화면에 보이는 행만 묶어서 요청한다.
            // 비정상적인 큰 메시지는 iPhone의 카탈로그 조회 부하를 막기 위해 제한한다.
            let uniqueSongIDs = Array(Set(songIDs.filter { !$0.isEmpty }).prefix(12))
            guard !uniqueSongIDs.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in self?.onPlaylistArtworkRequested?(uniqueSongIDs) }
            return
        }

        guard let payload = container["watchMusicCommand"] as? [String: Any],
              let action = payload["action"] as? String,
              let command = PhoneMusicPlaybackCommand(rawValue: action)
        else { return }
        let songID = payload["songID"] as? String
        let isPlaying = payload["isPlaying"] as? Bool
        let title = payload["title"] as? String
        let artist = payload["artist"] as? String
        DispatchQueue.main.async { [weak self] in self?.onCommand?(command, songID, isPlaying, title, artist) }
    }
}
