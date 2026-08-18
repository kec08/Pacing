import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFunctions

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
    var startDate: Date
    var endDate: Date
}

struct RunHistoryMonth: Identifiable, Hashable {
    let year: Int
    let month: Int

    var id: String { "\(year)-\(month)" }
    var label: String { "\(month)월" }
    var accessibilityLabel: String { "\(year)년 \(month)월" }
}

final class MyViewModel: ObservableObject {
    @Published var nickname: String = ""
    @Published var height: Int = 0
    @Published var weight: Int = 0
    @Published var profileVisibility: ProfileVisibility = .public
    @Published var profileImage: UIImage? = nil
    @Published var activityStatusText: String = "러닝 기록 없음"
    @Published var selectedPeriod: StatsPeriod = .week

    // 주: 0=이번주, -1=저번주, ...
    @Published var weekOffset: Int = 0
    // 월: 현재 연도의 선택된 월 (1~12)
    @Published var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    // 년: 선택된 연도
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())

    @Published var stats: MyStats = .empty
    @Published var chartEntries: [BarChartEntry] = []
    @Published var selectedChartEntryID: String?
    @Published var runHistory: [RunRecord] = []
    @Published private(set) var availableHistoryMonths: [RunHistoryMonth] = []
    @Published private(set) var selectedHistoryMonth: RunHistoryMonth?
    @Published var isLoading: Bool = true
    @Published var isDeletingAccount: Bool = false
    @Published var accountDeletionError: String?

    private let cal = Calendar.current

    init() {
        loadProfile()
        loadData()
    }

    private func loadProfile() {
        // UserDefaults 우선 (즉시 표시), Firestore에서 최신값 덮어씀
        nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"
        height   = UserDefaults.standard.integer(forKey: "height")
        weight   = UserDefaults.standard.integer(forKey: "weight")
        profileVisibility = ProfileVisibility(
            rawValue: UserDefaults.standard.string(forKey: "profileVisibility") ?? ""
        ) ?? .public
        UserDefaults.standard.removeObject(forKey: "age")
        profileImage = Self.decodeImage(UserDefaults.standard.string(forKey: "profileImageBase64"))

        guard let uid = Auth.auth().currentUser?.uid else { return }
        Task { @MainActor in
            if let data = try? await FirestoreService.shared.fetchUserProfile(uid: uid) {
                nickname = data["nickname"] as? String ?? nickname
                height   = data["height"]   as? Int    ?? height
                weight   = data["weight"]   as? Int    ?? weight
                profileVisibility = ProfileVisibility(
                    rawValue: data["profileVisibility"] as? String ?? ""
                ) ?? profileVisibility
                UserDefaults.standard.set(profileVisibility.rawValue, forKey: "profileVisibility")
                if let img = data["profileImageBase64"] as? String {
                    UserDefaults.standard.set(img, forKey: "profileImageBase64")
                    profileImage = Self.decodeImage(img)
                }
            }
        }
    }

    private static func decodeImage(_ base64: String?) -> UIImage? {
        guard let base64, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    func changePeriod(_ period: StatsPeriod) {
        selectedPeriod = period
        // 기간 변경 시 선택 초기화
        weekOffset = 0
        selectedMonth = cal.component(.month, from: Date())
        selectedYear = cal.component(.year, from: Date())
        selectedChartEntryID = nil
        loadData()
    }

    func applySelection() {
        loadData()
    }

    func loadData() {
        guard let uid = Auth.auth().currentUser?.uid else {
            applyData(records: [])
            isLoading = false
            return
        }
        Task { @MainActor in
            isLoading = true
            let records = (try? await FirestoreService.shared.fetchRunHistory(uid: uid, limit: 100)) ?? []
            applyData(records: records)
            isLoading = false
        }
    }

    private func applyData(records: [RunRecord]) {
        let now = Date()
        let filtered = filter(records: records)

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
        runHistory = records
            .filter { $0.startedAt <= now }
            .sorted(by: { $0.startedAt > $1.startedAt })
        updateHistoryMonths()
        activityStatusText = FriendActivityText.runningStatus(lastRunDate: runHistory.first?.startedAt)
    }

    var filteredRunHistory: [RunRecord] {
        guard let selectedHistoryMonth else { return [] }

        return runHistory.filter {
            cal.component(.year, from: $0.startedAt) == selectedHistoryMonth.year
                && cal.component(.month, from: $0.startedAt) == selectedHistoryMonth.month
        }
    }

    func selectHistoryMonth(_ month: RunHistoryMonth) {
        selectedHistoryMonth = month
    }

    private func updateHistoryMonths() {
        var seenMonthIDs = Set<String>()
        let months = runHistory.compactMap { record -> RunHistoryMonth? in
            let month = RunHistoryMonth(
                year: cal.component(.year, from: record.startedAt),
                month: cal.component(.month, from: record.startedAt)
            )
            return seenMonthIDs.insert(month.id).inserted ? month : nil
        }

        availableHistoryMonths = months
        if let selectedHistoryMonth,
           months.contains(selectedHistoryMonth) {
            return
        }
        selectedHistoryMonth = months.first
    }

    func toggleChartSelection(label: String) {
        selectedChartEntryID = selectedChartEntryID == label ? nil : label
    }

    var selectedChartEntry: BarChartEntry? {
        chartEntries.first { $0.id == selectedChartEntryID }
    }

    var selectedChartRuns: [RunRecord] {
        guard let entry = selectedChartEntry else { return [] }
        return runHistory.filter { $0.startedAt >= entry.startDate && $0.startedAt < entry.endDate }
    }

    var selectedChartDateText: String {
        guard let entry = selectedChartEntry else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = selectedPeriod == .week ? "yyyy년 M월 d일" : "yyyy년 M월"
        return formatter.string(from: entry.startDate)
    }

    var selectedChartDate: Date? {
        selectedChartEntry?.startDate
    }

    var selectedChartSuffixText: String {
        guard let entry = selectedChartEntry else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = selectedPeriod == .week ? "EEEE 러닝" : "러닝"
        return formatter.string(from: entry.startDate)
    }

    private func filter(records: [RunRecord]) -> [RunRecord] {
        let now = Date()
        switch selectedPeriod {
        case .week:
            let thisMonday = WeeklyDateRange.start(containing: now, calendar: cal)
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

    private func buildChartEntries(from records: [RunRecord]) -> [BarChartEntry] {
        let now = Date()

        switch selectedPeriod {
        case .week:
            let labels = ["월", "화", "수", "목", "금", "토", "일"]
            let monday = cal.date(byAdding: .day, value: weekOffset * 7, to: WeeklyDateRange.start(containing: now, calendar: cal))!
            return (0..<7).map { i in
                let date = cal.date(byAdding: .day, value: i, to: monday)!
                let next = cal.date(byAdding: .day, value: 1, to: date)!
                let km = records.filter { $0.startedAt >= date && $0.startedAt < next }.reduce(0) { $0 + $1.distance }
                return BarChartEntry(label: labels[i], value: km, startDate: date, endDate: next)
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
                return BarChartEntry(label: "\(week + 1)주", value: km, startDate: start, endDate: end)
            }

        case .year:
            let monthLabels = ["1","2","3","4","5","6","7","8","9","10","11","12"]
            return (1...12).map { month in
                var c = DateComponents(); c.year = selectedYear; c.month = month
                let start = cal.date(from: c)!
                let end   = cal.date(byAdding: .month, value: 1, to: start)!
                let km = records.filter { $0.startedAt >= start && $0.startedAt < end }.reduce(0) { $0 + $1.distance }
                return BarChartEntry(label: monthLabels[month - 1], value: km, startDate: start, endDate: end)
            }

        case .all:
            return (0..<6).map { offset in
                let date  = cal.date(byAdding: .month, value: -(5 - offset), to: now)!
                var comps = cal.dateComponents([.year, .month], from: date)
                let start = cal.date(from: comps)!
                let end   = cal.date(byAdding: .month, value: 1, to: start)!
                comps.day = nil
                let km = records.filter { $0.startedAt >= start && $0.startedAt < end }.reduce(0) { $0 + $1.distance }
                return BarChartEntry(label: "\(cal.component(.month, from: date))월", value: km, startDate: start, endDate: end)
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
        try? Auth.auth().signOut()
        clearLocalSession(appState: appState)
    }

    func deleteAccount(appState: AppState) async {
        guard !isDeletingAccount else { return }

        isDeletingAccount = true
        accountDeletionError = nil
        defer { isDeletingAccount = false }

        do {
            let functions = Functions.functions(region: "asia-northeast3")
            _ = try await functions.httpsCallable("deleteAccount").call()
            try? Auth.auth().signOut()
            clearLocalSession(appState: appState)
        } catch {
            accountDeletionError = "계정을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    private func clearLocalSession(appState: AppState) {
        appState.isLoggedIn = false
        appState.isProfileComplete = false
        // 계정 전환 시 이전 프로필 잔상 방지
        let d = UserDefaults.standard
        ["nickname", "height", "weight", "age", "profileImageBase64"].forEach { d.removeObject(forKey: $0) }
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

    func saveProfile(
        nickname: String,
        height: Int,
        weight: Int,
        profileImage: UIImage?
    ) async throws {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else { return }

        let imageBase64 = profileImage
            .flatMap { resizedJPEG($0, max: 200) }
            .map { $0.base64EncodedString() }

        let defaults = UserDefaults.standard
        defaults.set(trimmedNickname, forKey: "nickname")
        defaults.set(height, forKey: "height")
        defaults.set(weight, forKey: "weight")
        defaults.removeObject(forKey: "age")
        if let imageBase64 {
            defaults.set(imageBase64, forKey: "profileImageBase64")
        }

        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await FirestoreService.shared.saveUserProfile(
            uid: uid,
            nickname: trimmedNickname,
            height: height,
            weight: weight,
            profileImageBase64: imageBase64
        )

        await MainActor.run {
            self.nickname = trimmedNickname
            self.height = height
            self.weight = weight
            self.profileImage = profileImage
        }
    }

    func saveProfileVisibility(_ visibility: ProfileVisibility) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await FirestoreService.shared.saveProfileVisibility(uid: uid, visibility: visibility)
        UserDefaults.standard.set(visibility.rawValue, forKey: "profileVisibility")
        profileVisibility = visibility
    }

    private func resizedJPEG(_ image: UIImage, max side: CGFloat) -> Data? {
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            let scale = Swift.max(side / image.size.width, side / image.size.height)
            let width = image.size.width * scale
            let height = image.size.height * scale
            let x = (side - width) / 2
            let y = (side - height) / 2
            image.draw(in: CGRect(x: x, y: y, width: width, height: height))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
