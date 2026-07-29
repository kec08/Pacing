import Foundation

struct SharedPlaylistSummary: Identifiable, Equatable {
    let id: String
    let ownerUID: String
    let ownerNickname: String
    let title: String
    let subtitle: String
    let artworkURL: String?
    let sourcePlaylistID: String?
    let sourcePlaylistURL: String?
    let trackCount: Int
    let updatedAt: Date?
    let tracks: [SharedPlaylistTrack]

    var effectiveArtworkURL: String? {
        if let artworkURL, !artworkURL.isEmpty {
            return artworkURL
        }

        return tracks.lazy.compactMap(\.effectiveArtworkURL).first
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
        guard let artworkURL, !artworkURL.isEmpty else { return nil }
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
