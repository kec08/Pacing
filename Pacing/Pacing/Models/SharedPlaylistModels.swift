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
}

struct SharedPlaylistTrack: Identifiable, Equatable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String
    let songStoreID: String?
    let artworkURL: String?
    let durationText: String
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

