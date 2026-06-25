import SwiftUI
import Charts

struct MyView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = MyViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    statsSection
                    Divider().padding(.horizontal, 20).padding(.top, 8)
                    historySection
                    Divider().padding(.horizontal, 20).padding(.top, 8)
                    settingsSection
                }
            }
            .background(Color.backgroundSecondary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // 네비게이션 바 회색 영역에 프로필 표시
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.main500)
                                .frame(width: 34, height: 34)
                            Text(String(vm.nickname.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(vm.nickname)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            if vm.height > 0 || vm.weight > 0 || vm.age > 0 {
                                HStack(spacing: 6) {
                                    if vm.height > 0 { Text("\(vm.height)cm") }
                                    if vm.weight > 0 { Text("\(vm.weight)kg") }
                                    if vm.age > 0    { Text("\(vm.age)세") }
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .refreshable { vm.loadData() }
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 기간 탭
            HStack(spacing: 0) {
                ForEach(StatsPeriod.allCases, id: \.self) { period in
                    Button {
                        vm.changePeriod(period)
                    } label: {
                        Text(period.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(vm.selectedPeriod == period ? Color.white : Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                vm.selectedPeriod == period
                                ? Color.main500
                                : Color.clear
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(3)
            .background(Color.gray100)
            .clipShape(Capsule())
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // 기간 레이블
            HStack(spacing: 4) {
                Text(vm.periodLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // 총 거리 (좌측 정렬)
            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%.1f", vm.stats.totalDistance))
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(Color.textPrimary)
                Text("킬로미터")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // 3개 통계 (좌측 정렬, 균등 간격)
            HStack(spacing: 0) {
                summaryColumn(value: "\(vm.stats.totalRuns)", label: "러닝")
                summaryColumn(value: vm.formattedPace(vm.stats.avgPace), label: "평균 페이스")
                summaryColumn(value: vm.formattedDuration(vm.stats.totalTime), label: "시간")
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 4)

            // 차트
            activityChart
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
    }

    private func summaryColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var activityChart: some View {
        let maxVal = (vm.chartEntries.map(\.value).max() ?? 1)
        let yMax = max(maxVal * 1.3, 2.0)

        Chart(vm.chartEntries) { entry in
            BarMark(
                x: .value("기간", entry.label),
                y: .value("km", entry.value)
            )
            .foregroundStyle(
                entry.value > 0 ? Color.main500 : Color.gray200
            )
            .cornerRadius(3)
        }
        .chartYScale(domain: 0...yMax)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { val in
                AxisValueLabel {
                    if let v = val.as(Double.self) {
                        Text(String(format: "%.1f", v))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(Color.gray200)
            }
        }
        .frame(height: 110)
    }

    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("최근 활동")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            if vm.runHistory.isEmpty {
                Text("러닝 기록이 없어요")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                ForEach(vm.runHistory) { record in
                    RunHistoryCard(record: record, vm: vm)
                        .padding(.horizontal, 20)
                }
            }
        }
        .padding(.bottom, 16)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "person.fill", label: "프로필 수정") {}
            Divider().padding(.leading, 52)
            settingsRow(icon: "rectangle.portrait.and.arrow.right", label: "로그아웃", tint: .accent500) {
                vm.logout(appState: appState)
            }
        }
        .background(Color.backgroundPrimary)
        .padding(.top, 8)
        .padding(.bottom, 40)
    }

    private func settingsRow(icon: String, label: String, tint: Color = .textPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
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
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}
