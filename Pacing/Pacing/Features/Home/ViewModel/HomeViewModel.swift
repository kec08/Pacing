import SwiftUI
import Combine
import FirebaseAuth
import UIKit

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var weeklyStats: WeeklyStats = WeeklyStats(totalDistance: 0, totalDuration: 0, avgPace: 0)
    @Published var recentRuns: [RunRecord] = []
    @Published var friendRecentRuns: [FriendRecentRunActivity] = []
    @Published var friendRecentSongs: [FriendRecentSongActivity] = []
    @Published private(set) var friendSongArtworkURLs: [String: String] = [:]
    @Published private(set) var isLoadingRuns: Bool = false
    @Published private(set) var isLoadingFriendRuns: Bool = false
    @Published private(set) var isLoadingFriendMusic: Bool = false
    @Published private(set) var runLoadError: String?
    @Published private(set) var friendRunsLoadError: String?
    @Published private(set) var friendMusicLoadError: String?
    @Published var nickname: String = "러너"

    var currentUID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    private let cal = Calendar.current
    private let musicService = AppleMusicRecommendationService.shared

    func loadHomeData() async {
        nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"

        guard let uid = Auth.auth().currentUser?.uid else {
            recentRuns = []
            weeklyStats = WeeklyStats(totalDistance: 0, totalDuration: 0, avgPace: 0)
            friendRecentRuns = []
            friendRecentSongs = []
            friendSongArtworkURLs = [:]
            isLoadingRuns = false
            isLoadingFriendRuns = false
            isLoadingFriendMusic = false
            return
        }

        isLoadingRuns = true
        isLoadingFriendRuns = true
        isLoadingFriendMusic = true
        runLoadError = nil
        friendRunsLoadError = nil
        friendMusicLoadError = nil

        async let runs: Void = loadRunData(uid: uid)
        async let friendRuns: Void = loadFriendRecentRuns(uid: uid)
        async let friendMusic: Void = loadFriendRecentMusic(uid: uid)
        _ = await (runs, friendRuns, friendMusic)
    }

    func retryRuns() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingRuns = true
        runLoadError = nil
        await loadRunData(uid: uid)
    }

    func retryFriendRecentMusic() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingFriendMusic = true
        friendMusicLoadError = nil
        await loadFriendRecentMusic(uid: uid)
    }

    func retryFriendRecentRuns() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingFriendRuns = true
        friendRunsLoadError = nil
        await loadFriendRecentRuns(uid: uid)
    }

    private func loadRunData(uid: String) async {
        defer { isLoadingRuns = false }

        do {
            let records = try await FirestoreService.shared.fetchRunHistory(uid: uid, limit: 100)
            recentRuns = Array(records.prefix(3))
            weeklyStats = calcWeeklyStats(from: records)
        } catch {
            recentRuns = []
            weeklyStats = WeeklyStats(totalDistance: 0, totalDuration: 0, avgPace: 0)
            runLoadError = "러닝 기록을 불러오지 못했어요."
        }
    }

    private func loadFriendRecentMusic(uid: String) async {
        defer { isLoadingFriendMusic = false }

        do {
            let activities = try await FirestoreService.shared.fetchFriendsRecentSongs(currentUID: uid)
            friendRecentSongs = activities
            friendSongArtworkURLs = await resolveMissingFriendSongArtworkURLs(for: activities)
        } catch {
            friendRecentSongs = []
            friendSongArtworkURLs = [:]
            friendMusicLoadError = "친구가 최근에 들은 음악을 불러오지 못했어요."
        }
    }

    private func resolveMissingFriendSongArtworkURLs(
        for activities: [FriendRecentSongActivity]
    ) async -> [String: String] {
        let activitiesNeedingRemoteArtwork = activities.filter {
            !hasDecodableArtworkData($0.song.artworkData)
        }

        var artworkURLs: [String: String] = [:]
        for batchStartIndex in stride(from: 0, to: activitiesNeedingRemoteArtwork.count, by: 4) {
            let batch = activitiesNeedingRemoteArtwork[
                batchStartIndex..<min(batchStartIndex + 4, activitiesNeedingRemoteArtwork.count)
            ]

            await withTaskGroup(of: (String, String?).self) { group in
                for activity in batch {
                    let activityID = activity.id
                    let title = activity.song.title
                    let artistName = activity.song.artistName
                    group.addTask { [musicService] in
                        let artworkURL = await musicService.resolvedRecentSongArtworkURL(
                            title: title,
                            artistName: artistName
                        )
                        return (activityID, artworkURL)
                    }
                }

                for await (activityID, artworkURL) in group {
                    if let artworkURL, !artworkURL.isEmpty {
                        artworkURLs[activityID] = artworkURL
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

    private func loadFriendRecentRuns(uid: String) async {
        defer { isLoadingFriendRuns = false }

        do {
            friendRecentRuns = try await FirestoreService.shared.fetchFriendsRecentRuns(currentUID: uid)
        } catch {
            friendRecentRuns = []
            friendRunsLoadError = "친구의 최근 러닝을 불러오지 못했어요."
        }
    }

    private func calcWeeklyStats(from records: [RunRecord]) -> WeeklyStats {
        let now = Date()
        let weekInterval = WeeklyDateRange.interval(containing: now, calendar: cal)
        let weekly = records.filter { weekInterval.contains($0.startedAt) }
        let validPaceRecords = weekly.filter(\.isPaceValid)
        let dist = weekly.reduce(0.0) { $0 + $1.distance }
        let dur  = weekly.reduce(0)   { $0 + $1.duration }
        let validDistance = validPaceRecords.reduce(0.0) { $0 + $1.distance }
        let validDuration = validPaceRecords.reduce(0) { $0 + $1.duration }
        let pace = validDistance > 0 ? Double(validDuration) / 60.0 / validDistance : 0
        return WeeklyStats(totalDistance: dist, totalDuration: dur, avgPace: pace)
    }

    func formatPace(_ pace: Double) -> String {
        RunRecord.formattedPace(pace)
    }

    func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return String(format: "%d:%02d", h, m) }
        return String(format: "%d분", m)
    }

    func formatDistance(_ km: Double) -> String {
        String(format: "%.1f km", km)
    }

    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M월 d일"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }

    // ListenSessionRow는 다른 화면에서 재사용될 수 있어 표시 보조 메서드를 유지한다.
    func listenPartnerNickname(_ session: ListenSession) -> String {
        session.partnerNickname(for: currentUID)
    }

    func formatListenTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

}
