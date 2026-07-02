import SwiftUI
import Combine
import FirebaseAuth

final class HomeViewModel: ObservableObject {
    @Published var weeklyStats: WeeklyStats = WeeklyStats(totalDistance: 0, totalDuration: 0, avgPace: 0)
    @Published var recentRuns: [RunRecord] = []
    @Published var recentListenSessions: [ListenSession] = []
    @Published var isLoading: Bool = false
    @Published var nickname: String = "러너"

    var currentUID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    private let cal = Calendar.current

    func loadHomeData() async {
        await MainActor.run {
            isLoading = true
            nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            await MainActor.run { isLoading = false }
            return
        }

        async let recordsTask = FirestoreService.shared.fetchRunHistory(uid: uid, limit: 100)
        async let sessionsTask = RealtimeDBService.shared.fetchRecentListenSessions(uid: uid, limit: 10)

        let records = (try? await recordsTask) ?? []
        let sessions = (try? await sessionsTask) ?? []

        await MainActor.run {
            recentRuns = Array(records.prefix(3))
            weeklyStats = calcWeeklyStats(from: records)
            recentListenSessions = sessions
            isLoading = false
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
