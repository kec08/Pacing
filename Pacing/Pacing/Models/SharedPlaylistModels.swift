import Foundation

struct SharedPlaylistSummary: Identifiable, Equatable {
    let id: String
    let ownerUID: String
    let ownerNickname: String
    let title: String
    let subtitle: String
    let artworkURL: String?
    let artworkData: String?
    let sourcePlaylistID: String?
    let sourcePlaylistURL: String?
    let trackCount: Int
    let updatedAt: Date?
    let tracks: [SharedPlaylistTrack]

    var effectiveArtworkURL: String? {
        // 목록 미리보기에서는 첫 곡의 오래된 musicKit:// URL 때문에 대표 커버가
        // 가려지지 않도록, 실제로 표시 가능한 수록곡 커버를 순서대로 찾는다.
        if let trackArtworkURL = tracks.lazy
            .compactMap(\.effectiveArtworkURL)
            .first {
            return trackArtworkURL
        }
        guard Self.isDisplayableArtworkURL(artworkURL) else { return nil }
        return artworkURL
    }

    private static func isDisplayableArtworkURL(_ value: String?) -> Bool {
        guard let value,
              let url = URL(string: value),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else {
            return false
        }
        return true
    }
}

struct SharedPlaylistTrack: Identifiable, Equatable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String
    let songStoreID: String?
    let artworkURL: String?
    let durationText: String

    var effectiveArtworkURL: String? {
        guard let artworkURL,
              let url = URL(string: artworkURL),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else {
            return nil
        }
        return artworkURL
    }
}

struct RecommendedStationItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let artworkURL: String?
}

enum SharedPlaylistSaveState: Equatable {
    case idle
    case saving
    case saved
}
