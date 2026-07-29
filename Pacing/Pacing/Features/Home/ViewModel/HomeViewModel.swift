import SwiftUI
import Combine
import FirebaseAuth

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var weeklyStats: WeeklyStats = WeeklyStats(totalDistance: 0, totalDuration: 0, avgPace: 0)
    @Published var recentRuns: [RunRecord] = []
    @Published var recentListenSessions: [ListenSession] = []
    @Published private(set) var isLoadingRuns: Bool = false
    @Published private(set) var isLoadingListenSessions: Bool = false
    @Published private(set) var runLoadError: String?
    @Published private(set) var listenSessionLoadError: String?
    @Published var nickname: String = "러너"

    var currentUID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    private let cal = Calendar.current

    func loadHomeData() async {
        nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"

        guard let uid = Auth.auth().currentUser?.uid else {
            recentRuns = []
            weeklyStats = WeeklyStats(totalDistance: 0, totalDuration: 0, avgPace: 0)
            recentListenSessions = []
            isLoadingRuns = false
            isLoadingListenSessions = false
            return
        }

        isLoadingRuns = true
        isLoadingListenSessions = true
        runLoadError = nil
        listenSessionLoadError = nil

        async let runs: Void = loadRunData(uid: uid)
        async let sessions: Void = loadListenSessionData(uid: uid)
        _ = await (runs, sessions)
    }

    func retryRuns() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingRuns = true
        runLoadError = nil
        await loadRunData(uid: uid)
    }

    func retryListenSessions() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingListenSessions = true
        listenSessionLoadError = nil
        await loadListenSessionData(uid: uid)
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

    private func loadListenSessionData(uid: String) async {
        defer { isLoadingListenSessions = false }

        do {
            recentListenSessions = try await RealtimeDBService.shared.fetchRecentListenSessions(uid: uid, limit: 10)
        } catch {
            recentListenSessions = []
            listenSessionLoadError = "같이 들은 러너를 불러오지 못했어요."
        }
    }

    private func calcWeeklyStats(from records: [RunRecord]) -> WeeklyStats {
        let now = Date()
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) else {
            return WeeklyStats(totalDistance: 0, totalDuration: 0, avgPace: 0)
        }
        let weekly = records.filter { $0.startedAt >= weekStart && $0.startedAt < weekEnd }
        let dist = weekly.reduce(0.0) { $0 + $1.distance }
        let dur  = weekly.reduce(0)   { $0 + $1.duration }
        let pace = weekly.isEmpty ? 0.0 : weekly.reduce(0.0) { $0 + $1.avgPace } / Double(weekly.count)
        return WeeklyStats(totalDistance: dist, totalDuration: dur, avgPace: pace)
    }

    func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--'--\"" }
        let min = Int(pace)
        let sec = Int((pace - Double(min)) * 60)
        return String(format: "%d'%02d\"", min, sec)
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
