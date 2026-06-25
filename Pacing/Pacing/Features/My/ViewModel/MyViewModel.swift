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

    // 주: 0=이번주, -1=저번주, ...
    @Published var weekOffset: Int = 0
    // 월: 현재 연도의 선택된 월 (1~12)
    @Published var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    // 년: 선택된 연도
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())

    @Published var stats: MyStats = .empty
    @Published var chartEntries: [BarChartEntry] = []
    @Published var runHistory: [RunRecord] = []

    private let cal = Calendar.current

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
        // 기간 변경 시 선택 초기화
        weekOffset = 0
        selectedMonth = cal.component(.month, from: Date())
        selectedYear = cal.component(.year, from: Date())
        loadData()
    }

    func applySelection() {
        loadData()
    }

    func loadData() {
        let all = RunRecord.dummies
        let filtered = filter(records: all)

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

    private func filter(records: [RunRecord]) -> [RunRecord] {
        let now = Date()
        switch selectedPeriod {
        case .week:
            // 이번 주 시작 = 월요일 기준
            let thisMonday = mondayOfWeek(containing: now)
            let start = cal.date(byAdding: .day, value: weekOffset * 7, to: thisMonday)!
            let end   = cal.date(byAdding: .day, value: 7, to: start)!
            return records.filter { $0.startedAt >= start && $0.startedAt < end }
        case .month:
            let year = cal.component(.year, from: now)
            var comps = DateComponents(); comps.year = year; comps.month = selectedMonth
            let start = cal.date(from: comps)!
            let end   = cal.date(byAdding: .month, value: 1, to: start)!
            return records.filter { $0.startedAt >= start && $0.startedAt < end }
        case .year:
            var comps = DateComponents(); comps.year = selectedYear
            let start = cal.date(from: comps)!
            let end   = cal.date(byAdding: .year, value: 1, to: start)!
            return records.filter { $0.startedAt >= start && $0.startedAt < end }
        case .all:
            return records
        }
    }

    private func mondayOfWeek(containing date: Date) -> Date {
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        comps.weekday = 2 // 월요일
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    private func buildChartEntries(from records: [RunRecord]) -> [BarChartEntry] {
        let now = Date()

        switch selectedPeriod {
        case .week:
            let labels = ["월", "화", "수", "목", "금", "토", "일"]
            let monday = cal.date(byAdding: .day, value: weekOffset * 7, to: mondayOfWeek(containing: now))!
            return (0..<7).map { i in
                let date = cal.date(byAdding: .day, value: i, to: monday)!
                let next = cal.date(byAdding: .day, value: 1, to: date)!
                let km = records.filter { $0.startedAt >= date && $0.startedAt < next }.reduce(0) { $0 + $1.distance }
                return BarChartEntry(label: labels[i], value: km)
            }

        case .month:
            let year = cal.component(.year, from: now)
            var comps = DateComponents(); comps.year = year; comps.month = selectedMonth
            let monthStart = cal.date(from: comps)!
            let weeksInMonth = 5
            return (0..<weeksInMonth).map { week in
                let start = cal.date(byAdding: .weekOfMonth, value: week, to: monthStart)!
                let end   = cal.date(byAdding: .weekOfMonth, value: 1, to: start)!
                let km = records.filter { $0.startedAt >= start && $0.startedAt < end }.reduce(0) { $0 + $1.distance }
                return BarChartEntry(label: "\(week + 1)주", value: km)
            }

        case .year:
            let monthLabels = ["1","2","3","4","5","6","7","8","9","10","11","12"]
            return (1...12).map { month in
                var c = DateComponents(); c.year = selectedYear; c.month = month
                let start = cal.date(from: c)!
                let end   = cal.date(byAdding: .month, value: 1, to: start)!
                let km = records.filter { $0.startedAt >= start && $0.startedAt < end }.reduce(0) { $0 + $1.distance }
                return BarChartEntry(label: monthLabels[month - 1], value: km)
            }

        case .all:
            return (0..<6).map { offset in
                let date  = cal.date(byAdding: .month, value: -(5 - offset), to: now)!
                var comps = cal.dateComponents([.year, .month], from: date)
                let start = cal.date(from: comps)!
                let end   = cal.date(byAdding: .month, value: 1, to: start)!
                comps.day = nil
                let km = records.filter { $0.startedAt >= start && $0.startedAt < end }.reduce(0) { $0 + $1.distance }
                return BarChartEntry(label: "\(cal.component(.month, from: date))월", value: km)
            }
        }
    }

    var periodLabel: String {
        let now = Date()
        switch selectedPeriod {
        case .week:
            if weekOffset == 0 { return "이번 주" }
            if weekOffset == -1 { return "저번 주" }
            return "\(-weekOffset)주 전"
        case .month:
            return "\(cal.component(.year, from: now))년 \(selectedMonth)월"
        case .year:
            return "\(selectedYear)년"
        case .all:
            return "전체"
        }
    }

    // 주 피커용: 이번 주 ~ 4주 전 (5개)
    var weekOptions: [(offset: Int, label: String)] {
        (0 ..< 5).map { i in
            let offset = -i
            if offset == 0  { return (0,  "이번 주") }
            if offset == -1 { return (-1, "저번 주") }
            return (offset, "\(i)주 전")
        }
    }

    // 월 피커용: 현재 연도 1월 ~ 이번 달
    var monthOptions: [Int] {
        let currentMonth = cal.component(.month, from: Date())
        return Array(1...currentMonth)
    }

    // 년 피커용: 2023 ~ 이번 해
    var yearOptions: [Int] {
        let currentYear = cal.component(.year, from: Date())
        return Array(stride(from: currentYear, through: 2023, by: -1))
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
