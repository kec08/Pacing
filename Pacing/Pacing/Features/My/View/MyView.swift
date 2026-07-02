import SwiftUI
import Charts

struct MyView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = MyViewModel()
    @State private var showPicker = false
    @State private var showAllHistory = false
    @State private var showLogoutAlert = false
    @State private var showProfileEdit = false

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
        .sheet(isPresented: $showPicker) {
            periodPickerSheet
        }
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView(vm: vm)
        }
    }

    // MARK: - Period Picker Sheet
    @ViewBuilder
    private var periodPickerSheet: some View {
        VStack(spacing: 0) {
            // 핸들
            Capsule()
                .fill(Color.gray300)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text(vm.selectedPeriod == .week ? "주 선택" : vm.selectedPeriod == .month ? "월 선택" : "년도 선택")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(.bottom, 24)

            switch vm.selectedPeriod {
            case .week:
                Picker("주", selection: $vm.weekOffset) {
                    ForEach(vm.weekOptions, id: \.offset) { option in
                        Text(option.label).tag(option.offset)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 160)
                .background(Color.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)

            case .month:
                HStack(spacing: 12) {
                    // 년도 (현재 연도 고정)
                    Picker("년도", selection: .constant(Calendar.current.component(.year, from: Date()))) {
                        Text("\(Calendar.current.component(.year, from: Date()))년")
                            .tag(Calendar.current.component(.year, from: Date()))
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Picker("월", selection: $vm.selectedMonth) {
                        ForEach(vm.monthOptions, id: \.self) { month in
                            Text("\(month)월").tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

            case .year:
                Picker("년도", selection: $vm.selectedYear) {
                    ForEach(vm.yearOptions, id: \.self) { year in
                        Text("\(year)년").tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 160)
                .background(Color.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)

            case .all:
                EmptyView()
            }

            Spacer()

            Button {
                vm.applySelection()
                showPicker = false
            } label: {
                Text("선택")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.main500)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                if let img = vm.profileImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.main500)
                        .frame(width: 44, height: 44)
                    Text(String(vm.nickname.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(vm.nickname)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(vm.activityStatusText)
                    .font(.system(size: 12, weight: FriendActivityText.isTodayStatus(vm.activityStatusText) ? .bold : .medium))
                    .foregroundStyle(FriendActivityText.isTodayStatus(vm.activityStatusText) ? Color.green : Color.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Stats Section
    @ViewBuilder
    private var statsSection: some View {
        if vm.isLoading && vm.runHistory.isEmpty {
            myStatsSkeleton
        } else {
            statsContent
        }
    }

    private var statsContent: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 기간 탭
            periodFilterTab
                .padding(.horizontal, 28)
                .padding(.top, 22)

            // 기간 레이블 (탭 → 피커 시트)
            Button {
                if vm.selectedPeriod != .all { showPicker = true }
            } label: {
                HStack(spacing: 5) {
                    Text(vm.periodLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    if vm.selectedPeriod != .all {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)

            // 총 거리 — 핑크 포인트 accent
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(String(format: "%.1f", vm.stats.totalDistance))
                        .font(.system(size: 68, weight: .heavy))
                        .foregroundStyle(Color.textPrimary)
                    Text("km")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.main500)
                        .padding(.bottom, 6)
                }
                Text("이번 \(vm.selectedPeriod == .week ? "주" : vm.selectedPeriod == .month ? "달" : vm.selectedPeriod == .year ? "해" : "기간")의 총 거리")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 6)

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

    private var myStatsSkeleton: some View {
        VStack(alignment: .leading, spacing: 18) {
            SkeletonBlock(height: 42, cornerRadius: 21)
                .padding(.horizontal, 28)
                .padding(.top, 22)

            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(width: 160, height: 58, cornerRadius: 12)
                SkeletonBlock(width: 118, height: 14, cornerRadius: 7)
            }
            .padding(.horizontal, 28)

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBlock(height: 76, cornerRadius: 14)
                }
            }
            .padding(.horizontal, 28)

            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(width: 72, height: 13, cornerRadius: 7)
                SkeletonBlock(height: 160, cornerRadius: 16)
            }
            .padding(.horizontal, 28)
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

            if vm.isLoading && vm.runHistory.isEmpty {
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonRow()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal, 20)
                    }
                }
            } else if vm.runHistory.isEmpty {
                Text("러닝 기록이 없어요")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                let displayed = showAllHistory ? vm.runHistory : Array(vm.runHistory.prefix(5))
                ForEach(displayed) { record in
                    RunHistoryCard(record: record, vm: vm)
                        .padding(.horizontal, 20)
                }

                if vm.runHistory.count > 5 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showAllHistory.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showAllHistory ? "접기" : "더보기 (\(vm.runHistory.count - 5)개)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.main500)
                            Image(systemName: showAllHistory ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.main500)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .padding(.bottom, 22)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "person.fill", label: "프로필 수정") {
                showProfileEdit = true
            }
            Divider().padding(.leading, 54)
            settingsRow(icon: "rectangle.portrait.and.arrow.right", label: "로그아웃", tint: .accent500) {
                showLogoutAlert = true
            }
            .alert("로그아웃", isPresented: $showLogoutAlert) {
                Button("취소", role: .cancel) {}
                Button("로그아웃", role: .destructive) {
                    vm.logout(appState: appState)
                }
            } message: {
                Text("로그아웃 하시겠습니까?")
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
