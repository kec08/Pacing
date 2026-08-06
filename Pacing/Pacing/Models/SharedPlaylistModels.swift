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
        // 친구 플레이리스트의 목록·상세 대표 이미지는 항상 첫 번째 수록곡의
        // 앨범 커버를 사용한다. 다른 수록곡 커버로 대체하면 두 화면이 달라진다.
        if let firstTrack = tracks.first {
            return firstTrack.effectiveArtworkURL
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
