import SwiftUI
import Charts

struct MyView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = MyViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader
                statsSection
                Divider().padding(.top, 8)
                historySection
                Divider().padding(.top, 8)
                settingsSection
            }
        }
        .background(Color.backgroundPrimary)
        .refreshable { vm.loadData() }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.main500)
                    .frame(width: 44, height: 44)
                Text(String(vm.nickname.prefix(1)))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(vm.nickname)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                if vm.height > 0 || vm.weight > 0 || vm.age > 0 {
                    HStack(spacing: 6) {
                        if vm.height > 0 { Text("\(vm.height)cm") }
                        if vm.weight > 0 { Text("\(vm.weight)kg") }
                        if vm.age > 0    { Text("\(vm.age)세") }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 기간 탭
            periodFilterTab
                .padding(.horizontal, 28)
                .padding(.top, 22)

            // 기간 레이블
            HStack(spacing: 5) {
                Text(vm.periodLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)

            // 총 거리 — 핑크 포인트 accent
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", vm.stats.totalDistance))
                        .font(.system(size: 54, weight: .heavy))
                        .foregroundStyle(Color.textPrimary)
                    Text("km")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.main500)
                        .padding(.bottom, 4)
                }
                Text("이번 \(vm.selectedPeriod == .week ? "주" : vm.selectedPeriod == .month ? "달" : vm.selectedPeriod == .year ? "해" : "기간")의 총 거리")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)

            // 3개 통계 카드
            HStack(spacing: 10) {
                statCard(
                    icon: "figure.run",
                    value: "\(vm.stats.totalRuns)",
                    unit: "회",
                    label: "러닝"
                )
                statCard(
                    icon: "stopwatch",
                    value: vm.formattedPace(vm.stats.avgPace),
                    unit: "/km",
                    label: "평균 페이스"
                )
                statCard(
                    icon: "clock",
                    value: vm.formattedDuration(vm.stats.totalTime),
                    unit: "",
                    label: "총 시간"
                )
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)

            // 차트
            activityChart
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
    }

    private func statCard(icon: String, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.main500)
                .frame(height: 24)

            Spacer().frame(height: 10)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer().frame(height: 6)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // 드래그 선택 탭
    private var periodFilterTab: some View {
        GeometryReader { geo in
            let count = StatsPeriod.allCases.count
            let itemWidth = geo.size.width / CGFloat(count)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray100)
                Capsule()
                    .fill(Color.main500)
                    .frame(width: itemWidth - 6)
                    .padding(.vertical, 3)
                    .offset(x: CGFloat(StatsPeriod.allCases.firstIndex(of: vm.selectedPeriod) ?? 0) * itemWidth + 3)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: vm.selectedPeriod)
                HStack(spacing: 0) {
                    ForEach(StatsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(vm.selectedPeriod == period ? Color.white : Color.textSecondary)
                            .frame(width: itemWidth)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                            .onTapGesture { vm.changePeriod(period) }
                    }
                }
            }
            .frame(height: 42)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let idx = max(0, min(count - 1, Int(drag.location.x / itemWidth)))
                        let period = StatsPeriod.allCases[idx]
                        if period != vm.selectedPeriod { vm.changePeriod(period) }
                    }
            )
        }
        .frame(height: 42)
    }

    @ViewBuilder
    private var activityChart: some View {
        let maxVal = vm.chartEntries.map(\.value).max() ?? 1
        let yMax = max(maxVal * 1.3, 2.0)

        VStack(alignment: .leading, spacing: 12) {
            // 차트 제목
            Text("거리 추이")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            Chart(vm.chartEntries) { entry in
                BarMark(
                    x: .value("기간", entry.label),
                    y: .value("km", entry.value)
                )
                .foregroundStyle(
                    entry.value > 0
                    ? LinearGradient(
                        colors: [Color.main500, Color.main300],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : LinearGradient(colors: [Color.gray100], startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(5)
            }
            .chartYScale(domain: 0...yMax)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { val in
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text(String(format: "%.1f", v))
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.gray100)
                }
            }
            .frame(height: 160)
        }
    }

    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 활동")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 28)
                .padding(.top, 22)

            if vm.runHistory.isEmpty {
                Text("러닝 기록이 없어요")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                ForEach(vm.runHistory) { record in
                    RunHistoryCard(record: record, vm: vm)
                        .padding(.horizontal, 20)
                }
            }
        }
        .padding(.bottom, 22)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "person.fill", label: "프로필 수정") {}
            Divider().padding(.leading, 54)
            settingsRow(icon: "rectangle.portrait.and.arrow.right", label: "로그아웃", tint: .accent500) {
                vm.logout(appState: appState)
            }
        }
        .background(Color.backgroundPrimary)
        .padding(.top, 8)
        .padding(.bottom, 48)
    }

    private func settingsRow(icon: String, label: String, tint: Color = .textPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 28)
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(tint)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.gray300)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
    }
}
