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
    let title: String
    let artist: String
    let artworkURL: String?
    /// Watch가 iPhone과 다른 네트워크 상태여도 현재 앨범 아트를 표시하도록 축소 JPEG를 함께 전달합니다.
    let artworkData: Data?
    let isPlaying: Bool
    let recentlyPlayed: [PhoneMusicTrack]

    func removingRecentArtworkData() -> Self {
        Self(
            title: title,
            artist: artist,
            artworkURL: artworkURL,
            artworkData: artworkData,
            isPlaying: isPlaying,
            recentlyPlayed: recentlyPlayed.map {
                PhoneMusicTrack(id: $0.id, title: $0.title, artist: $0.artist, artworkURL: $0.artworkURL, artworkData: nil)
            }
        )
    }

    func removingAllArtworkData() -> Self {
        removingRecentArtworkData().withCurrentArtworkData(nil)
    }

    private func withCurrentArtworkData(_ artworkData: Data?) -> Self {
        Self(title: title, artist: artist, artworkURL: artworkURL, artworkData: artworkData, isPlaying: isPlaying, recentlyPlayed: recentlyPlayed)
    }
}

enum PhoneMusicPlaybackCommand: String, Codable {
    case togglePlayback
    case previous
    case next
    case play
}

enum WatchMusicArtworkEncoder {
    static func encodeCurrentArtwork(_ image: UIImage) -> Data? {
        encode(image, maximumPixelSize: 160, maximumByteCount: 10_000)
    }

    static func encodeRecentArtwork(_ image: UIImage) -> Data? {
        encode(image, maximumPixelSize: 56, maximumByteCount: 2_000)
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
