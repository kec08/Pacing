import Foundation
import Combine
import FirebaseAuth
import UIKit

@MainActor
final class FriendProfileViewModel: ObservableObject {
    @Published var friend: FriendUser
    @Published var relationship: FriendRelationship
    @Published var stats: FriendProfileStats = .empty
    @Published var recentRuns: [RunRecord] = []
    @Published var recentSongs: [FriendRecentSong] = []
    @Published var recentSongArtworkURLs: [String: String] = [:]
    @Published var isLoading: Bool = false
    @Published var isUpdatingRelationship: Bool = false
    @Published var errorMessage: String?

    private let service = FirestoreService.shared
    private let musicService = AppleMusicRecommendationService.shared

    init(friend: FriendUser, initialRelationship: FriendRelationship) {
        self.friend = friend
        self.relationship = initialRelationship
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let profileTask = service.fetchFriendUserProfile(uid: friend.id, source: .friend)
            async let statsTask = service.fetchFriendProfileStats(uid: friend.id)
            async let runsTask = service.fetchRunHistory(uid: friend.id, limit: 5)
            async let songsTask = service.fetchRecentSongs(uid: friend.id, limit: 5)
            async let relationshipTask = fetchRelationship()

            friend = try await profileTask
            stats = try await statsTask
            recentRuns = try await runsTask
            recentSongs = try await songsTask
            recentSongArtworkURLs = await resolveArtworkURLs(for: recentSongs)
            relationship = try await relationshipTask
        } catch {
            errorMessage = "친구 프로필을 불러오지 못했어요."
        }

        isLoading = false
    }

    private func resolveArtworkURLs(for songs: [FriendRecentSong]) async -> [String: String] {
        let songsNeedingRemoteArtwork = songs.filter {
            !hasDecodableArtworkData($0.artworkData)
        }

        var artworkURLs: [String: String] = [:]
        for batchStartIndex in stride(from: 0, to: songsNeedingRemoteArtwork.count, by: 4) {
            let batch = songsNeedingRemoteArtwork[
                batchStartIndex..<min(batchStartIndex + 4, songsNeedingRemoteArtwork.count)
            ]

            await withTaskGroup(of: (String, String?).self) { group in
                for song in batch {
                    let songID = song.id
                    let title = song.title
                    let artistName = song.artistName
                    group.addTask { [musicService] in
                        let artworkURL = await musicService.resolvedRecentSongArtworkURL(
                            title: title,
                            artistName: artistName
                        )
                        return (songID, artworkURL)
                    }
                }

                for await (songID, artworkURL) in group {
                    if let artworkURL, !artworkURL.isEmpty {
                        artworkURLs[songID] = artworkURL
                    }
                }
            }
        }

        await ArtworkImageStore.shared.prefetch(urlStrings: Array(artworkURLs.values))
        return artworkURLs
    }

    private func hasDecodableArtworkData(_ encodedArtwork: String?) -> Bool {
        guard let encodedArtwork,
              let data = Data(base64Encoded: encodedArtwork)
        else {
            return false
        }
        return UIImage(data: data) != nil
    }

    func sendFriendRequest() async -> Bool {
        guard relationship == .none, let uid = Auth.auth().currentUser?.uid else {
            return false
        }

        isUpdatingRelationship = true
        errorMessage = nil

        do {
            try await service.sendFriendRequest(from: uid, to: friend.id)
            relationship = .requestPending
            isUpdatingRelationship = false
            return true
        } catch {
            errorMessage = "친구 요청을 보내지 못했어요."
            isUpdatingRelationship = false
            return false
        }
    }

    func cancelFriendRequest() async -> Bool {
        guard relationship == .requestPending, let uid = Auth.auth().currentUser?.uid else {
            return false
        }

        isUpdatingRelationship = true
        errorMessage = nil

        do {
            try await service.cancelSentFriendRequest(from: uid, to: friend.id)
            relationship = .none
            isUpdatingRelationship = false
            return true
        } catch {
            errorMessage = "친구 요청을 취소하지 못했어요."
            isUpdatingRelationship = false
            return false
        }
    }

    private func fetchRelationship() async throws -> FriendRelationship {
        guard let uid = Auth.auth().currentUser?.uid else {
            return relationship
        }

        return try await service.fetchFriendRelationship(currentUID: uid, targetUID: friend.id)
    }

    var formattedAveragePace: String {
        guard stats.averagePace > 0 else { return "--'--\"" }
        let minutes = Int(stats.averagePace)
        let seconds = Int((stats.averagePace - Double(minutes)) * 60)
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    var formattedTotalDuration: String {
        let hours = stats.totalDuration / 3600
        let minutes = (stats.totalDuration % 3600) / 60

        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }

        return "\(minutes)분"
    }

    var formattedTotalDistance: String {
        String(format: "%.1fkm", stats.totalDistance)
    }

    var activityText: String {
        FriendActivityText.runningStatus(lastRunDate: stats.lastRunDate)
    }

    var isTodayActivity: Bool {
        FriendActivityText.isTodayStatus(activityText)
    }

    var actionTitle: String {
        switch relationship {
        case .friend:
            return "친구"
        case .requestPending:
            return "요청 대기중"
        case .none:
            return "친구 추가"
        }
    }

    var canTapAction: Bool {
        relationship != .friend && !isUpdatingRelationship
    }
}
