import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    headerSection
                    weeklyStatsSection
                    recentRunsSection
                    listenSessionSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.backgroundSecondary)
            .refreshable { await vm.loadHomeData() }
            .navigationBarHidden(true)
        }
        .task { await vm.loadHomeData() }
    }

    // MARK: - 헤더
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(todayString)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
            Text("안녕하세요, \(vm.nickname) 님")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - 이번 주 통계
    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("이번 주 러닝")
            if vm.weeklyStats.isEmpty {
                emptyCard("이번 주 첫 러닝을 시작해보세요")
            } else {
                WeeklyStatsCard(stats: vm.weeklyStats, vm: vm)
            }
        }
    }

    // MARK: - 최근 러닝 기록
    private var recentRunsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("최근 러닝")
            if vm.recentRuns.isEmpty {
                emptyCard("아직 러닝 기록이 없어요")
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.recentRuns.prefix(5)) { run in
                        RecentRunRow(run: run, vm: vm)
                    }
                }
            }
        }
    }

    // MARK: - 같이 들은 러너
    private var listenSessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("같이 들은 러너")
            if vm.recentListenSessions.isEmpty {
                emptyCard("아직 같이 들은 러너가 없어요")
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.recentListenSessions.prefix(3)) { session in
                        ListenSessionRow(session: session, vm: vm)
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - 공통 컴포넌트
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.textPrimary)
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy년 M월 d일 EEEE"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: Date())
    }
}
