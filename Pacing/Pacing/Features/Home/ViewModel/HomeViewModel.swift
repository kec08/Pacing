import SwiftUI
import Combine

final class HomeViewModel: ObservableObject {
    @Published var weeklyStats: WeeklyStats = WeeklyStats(totalDistance: 0, totalDuration: 0, avgPace: 0)
    @Published var recentRuns: [RunRecord] = []
    @Published var recentListenSessions: [ListenSession] = []
    @Published var isLoading: Bool = false
    @Published var nickname: String = "러너"

    func loadHomeData() async {
        await MainActor.run { isLoading = true }
        // TODO: Firestore 연동으로 교체
        try? await Task.sleep(nanoseconds: 500_000_000)
        await MainActor.run {
            loadDummyData()
            isLoading = false
        }
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

    private func loadDummyData() {
        let now = Date()
        recentRuns = [
            RunRecord(id: "1", startedAt: now.addingTimeInterval(-86400),    duration: 2100, distance: 5.2,  avgPace: 6.7, routeCoordinates: []),
            RunRecord(id: "2", startedAt: now.addingTimeInterval(-172800),   duration: 3600, distance: 8.1,  avgPace: 7.4, routeCoordinates: []),
            RunRecord(id: "3", startedAt: now.addingTimeInterval(-345600),   duration: 1800, distance: 4.0,  avgPace: 7.5, routeCoordinates: []),
        ]
        weeklyStats = WeeklyStats(totalDistance: 17.3, totalDuration: 7500, avgPace: 7.2)
        recentListenSessions = [
            ListenSession(id: "1", partnerNickname: "달리기좋아", songTitle: "Blinding Lights", date: now.addingTimeInterval(-86400)),
            ListenSession(id: "2", partnerNickname: "새벽러너",   songTitle: "As It Was",        date: now.addingTimeInterval(-172800)),
        ]
        nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"
    }
}
