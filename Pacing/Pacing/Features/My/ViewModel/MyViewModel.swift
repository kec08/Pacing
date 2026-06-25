import SwiftUI
import Combine

enum StatsPeriod: String, CaseIterable {
    case week = "주"
    case month = "월"
    case year = "년"
    case all = "전체"
}

struct MyStats {
    var totalDistance: Double = 0
    var totalRuns: Int = 0
    var avgPace: Double = 0
    var totalTime: Int = 0

    static let empty = MyStats()
}

struct BarChartEntry: Identifiable {
    var id: String { label }
    var label: String
    var value: Double
}

final class MyViewModel: ObservableObject {
    @Published var nickname: String = ""
    @Published var height: Int = 0
    @Published var weight: Int = 0
    @Published var age: Int = 0
    @Published var selectedPeriod: StatsPeriod = .week
    @Published var stats: MyStats = .empty
    @Published var chartEntries: [BarChartEntry] = []
    @Published var runHistory: [RunRecord] = []

    init() {
        loadProfile()
        loadData()
    }

    private func loadProfile() {
        nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"
        height   = UserDefaults.standard.integer(forKey: "height")
        weight   = UserDefaults.standard.integer(forKey: "weight")
        age      = UserDefaults.standard.integer(forKey: "age")
    }

    func changePeriod(_ period: StatsPeriod) {
        selectedPeriod = period
        loadData()
    }

    func loadData() {
        let all = RunRecord.dummies
        let filtered = filter(records: all, by: selectedPeriod)

        let totalDist = filtered.reduce(0) { $0 + $1.distance }
        let totalTime = filtered.reduce(0) { $0 + $1.duration }
        let avgPace = filtered.isEmpty ? 0 : filtered.reduce(0) { $0 + $1.avgPace } / Double(filtered.count)

        stats = MyStats(
            totalDistance: totalDist,
            totalRuns: filtered.count,
            avgPace: avgPace,
            totalTime: totalTime
        )

        chartEntries = buildChartEntries(from: filtered)
        runHistory = all.sorted(by: { $0.startedAt > $1.startedAt })
    }

    private func filter(records: [RunRecord], by period: StatsPeriod) -> [RunRecord] {
        let now = Date()
        let cal = Calendar.current
        switch period {
        case .week:
            let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!
            return records.filter { $0.startedAt >= start }
        case .month:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps)!
            return records.filter { $0.startedAt >= start }
        case .year:
            let comps = cal.dateComponents([.year], from: now)
            let start = cal.date(from: comps)!
            return records.filter { $0.startedAt >= start }
        case .all:
            return records
        }
    }

    private func buildChartEntries(from records: [RunRecord]) -> [BarChartEntry] {
        let cal = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .week:
            let labels = ["월", "화", "수", "목", "금", "토", "일"]
            return (0..<7).map { offset in
                let date = cal.date(byAdding: .day, value: -(6 - offset), to: cal.startOfDay(for: now))!
                let next = cal.date(byAdding: .day, value: 1, to: date)!
                let km = records.filter { $0.startedAt >= date && $0.startedAt < next }.reduce(0) { $0 + $1.distance }
                let weekday = cal.component(.weekday, from: date)
                let label = labels[(weekday + 5) % 7]
                return BarChartEntry(label: label, value: km)
            }

        case .month:
            let weeksInMonth = 5
            return (0..<weeksInMonth).map { week in
                let start = cal.date(byAdding: .weekOfMonth, value: week, to: cal.date(from: cal.dateComponents([.year, .month], from: now))!)!
                let end = cal.date(byAdding: .weekOfMonth, value: 1, to: start)!
                let km = records.filter { $0.startedAt >= start && $0.startedAt < end }.reduce(0) { $0 + $1.distance }
                return BarChartEntry(label: "\(week + 1)주", value: km)
            }

        case .year:
            let monthLabels = ["1","2","3","4","5","6","7","8","9","10","11","12"]
            let year = cal.component(.year, from: now)
            return (1...12).map { month in
                var comps = DateComponents(); comps.year = year; comps.month = month
                let start = cal.date(from: comps)!
                let end = cal.date(byAdding: .month, value: 1, to: start)!
                let km = records.filter { $0.startedAt >= start && $0.startedAt < end }.reduce(0) { $0 + $1.distance }
                return BarChartEntry(label: monthLabels[month - 1], value: km)
            }

        case .all:
            // 최근 6개월
            return (0..<6).map { offset in
                let date = cal.date(byAdding: .month, value: -(5 - offset), to: now)!
                var comps = cal.dateComponents([.year, .month], from: date)
                let start = cal.date(from: comps)!
                let end = cal.date(byAdding: .month, value: 1, to: start)!
                comps.day = nil
                let km = records.filter { $0.startedAt >= start && $0.startedAt < end }.reduce(0) { $0 + $1.distance }
                let label = "\(cal.component(.month, from: date))월"
                return BarChartEntry(label: label, value: km)
            }
        }
    }

    var periodLabel: String {
        let cal = Calendar.current
        let now = Date()
        switch selectedPeriod {
        case .week:
            return "이번 주"
        case .month:
            let year = cal.component(.year, from: now)
            let month = cal.component(.month, from: now)
            return "\(year)년 \(month)월"
        case .year:
            let year = cal.component(.year, from: now)
            return "\(year)년"
        case .all:
            return "전체"
        }
    }

    func logout(appState: AppState) {
        appState.isLoggedIn = false
        appState.isProfileComplete = false
    }

    func formattedPace(_ pace: Double) -> String {
        guard pace > 0 else { return "-'--\"" }
        let min = Int(pace)
        let sec = Int((pace - Double(min)) * 60)
        return String(format: "%d'%02d\"", min, sec)
    }

    func formattedDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
