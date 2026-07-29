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
                    friendRecentRunsSection
                    friendRecentMusicSection
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

    // MARK: - 친구 최근 러닝
    private var friendRecentRunsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("친구 최근 러닝")
            if vm.isLoadingFriendRuns && vm.friendRecentRuns.isEmpty {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonRow()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.backgroundPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            } else if let errorMessage = vm.friendRunsLoadError, vm.friendRecentRuns.isEmpty {
                errorCard(errorMessage) { Task { await vm.retryFriendRecentRuns() } }
            } else if vm.friendRecentRuns.isEmpty {
                emptyCard("친구의 최근 러닝이 없어요")
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.friendRecentRuns.prefix(3)) { activity in
                        FriendRecentRunRow(activity: activity, vm: vm)
                    }
                }
            }
        }
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
            if vm.isLoadingRuns && vm.weeklyStats.isEmpty {
                weeklyStatsSkeleton
            } else if let errorMessage = vm.runLoadError, vm.weeklyStats.isEmpty {
                errorCard(errorMessage) { Task { await vm.retryRuns() } }
            } else if vm.weeklyStats.isEmpty {
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
            if vm.isLoadingRuns && vm.recentRuns.isEmpty {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonRow()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.backgroundPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            } else if let errorMessage = vm.runLoadError, vm.recentRuns.isEmpty {
                errorCard(errorMessage) { Task { await vm.retryRuns() } }
            } else if vm.recentRuns.isEmpty {
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

    // MARK: - 친구 최근 음악
    private var friendRecentMusicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("친구가 최근에 들은 음악")
            if vm.isLoadingFriendMusic && vm.friendRecentSongs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonBlock(width: 88, height: 88, cornerRadius: 14)
                                SkeletonBlock(width: 52, height: 11, cornerRadius: 6)
                                SkeletonBlock(width: 78, height: 13, cornerRadius: 6)
                                SkeletonBlock(width: 62, height: 11, cornerRadius: 6)
                            }
                            .frame(width: 112, alignment: .leading)
                        }
                    }
                }
            } else if let errorMessage = vm.friendMusicLoadError, vm.friendRecentSongs.isEmpty {
                errorCard(errorMessage) { Task { await vm.retryFriendRecentMusic() } }
            } else if vm.friendRecentSongs.isEmpty {
                emptyCard("친구가 최근에 들은 음악이 없어요")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.friendRecentSongs) { activity in
                            FriendRecentMusicCard(activity: activity)
                        }
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

    private func errorCard(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)

            Button("다시 시도", action: retry)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.main500)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var weeklyStatsSkeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            SkeletonBlock(width: 96, height: 14)
            SkeletonBlock(width: 168, height: 32, cornerRadius: 10)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBlock(height: 64, cornerRadius: 14)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy년 M월 d일 EEEE"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: Date())
    }
}

private struct FriendRecentMusicCard: View {
    let activity: FriendRecentSongActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artwork
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(activity.friendNickname)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.main500)
                .lineLimit(1)

            Text(activity.song.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Text(activity.song.artistName)
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 112, alignment: .leading)
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkData = activity.song.artworkData,
           let data = Data(base64Encoded: artworkData),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RemoteArtworkView(urlString: activity.song.artworkURL)
        }
    }
}

private struct FriendRecentRunRow: View {
    let activity: FriendRecentRunActivity
    let vm: HomeViewModel

    var body: some View {
        NavigationLink {
            RunActivityDetailView(record: activity.run)
        } label: {
            HStack(spacing: 14) {
                RunRouteThumbnailView(coordinates: activity.run.routeCoordinates)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.friendNickname)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.main500)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(vm.formatDate(activity.run.startedAt))
                        Text("·")
                        Text(vm.formatDistance(activity.run.distance))
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)

                    HStack(spacing: 12) {
                        Text(vm.formatDuration(activity.run.duration))
                        Text(vm.formatPace(activity.run.avgPace) + "/km")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.gray300)
            }
            .padding(14)
            .background(Color.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityHint("친구의 러닝 활동 상세를 엽니다")
    }
}
