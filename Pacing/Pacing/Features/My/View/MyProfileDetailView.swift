import SwiftUI

struct MyProfileDetailView: View {
    @ObservedObject var myViewModel: MyViewModel
    @StateObject private var vm = MyProfileDetailViewModel()
    @State private var showProfileEdit = false

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 24) {
                    profileHeader
                    editAction
                    statsSection
                    recentRunsSection
                    recentSongsSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("내 프로필")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable {
            myViewModel.loadData()
            await vm.load()
        }
        .sheet(isPresented: $showProfileEdit, onDismiss: refreshAfterEdit) {
            ProfileEditView(vm: myViewModel)
        }
        .alert("내 프로필 오류", isPresented: errorBinding) {
            Button("확인", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.main200.opacity(0.38),
                Color.backgroundSecondary,
                Color.backgroundPrimary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            profileAvatar

            VStack(spacing: 4) {
                Text(myViewModel.nickname)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                if vm.isLoading {
                    SkeletonBlock(width: 96, height: 13, cornerRadius: 7)
                } else {
                    Text(vm.activityText)
                        .font(.system(size: 13, weight: vm.isTodayActivity ? .bold : .medium))
                        .foregroundStyle(vm.isTodayActivity ? Color.green : Color.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    private var profileAvatar: some View {
        ZStack {
            if let image = myViewModel.profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.main200.opacity(0.9), Color.main300.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(String(myViewModel.nickname.prefix(1)).isEmpty ? "러" : String(myViewModel.nickname.prefix(1)))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.main500)
            }
        }
        .frame(width: 104, height: 104)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
        }
        .shadow(color: Color.main500.opacity(0.12), radius: 14, y: 8)
    }

    private var editAction: some View {
        Button {
            showProfileEdit = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .bold))

                Text("프로필 편집")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(Color.main500)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white.opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.main500.opacity(0.08), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var statsSection: some View {
        Group {
            if vm.isLoading {
                HStack(spacing: 18) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: 8) {
                            SkeletonBlock(width: 64, height: 22, cornerRadius: 8)
                            SkeletonBlock(width: 48, height: 11, cornerRadius: 6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ProfileStatItem(title: "누적 거리", value: vm.formattedTotalDistance)
                    statDivider
                    ProfileStatItem(title: "운동 시간", value: vm.formattedTotalDuration)
                    statDivider
                    ProfileStatItem(title: "평균 페이스", value: vm.formattedAveragePace)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.gray300.opacity(0.7))
            .frame(width: 1, height: 34)
    }

    private var recentSongsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 들은 노래")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            if vm.isLoading && vm.recentSongs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonRow(avatarSize: 44)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                }
            } else if vm.recentSongs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.gray500)
                    Text("최근 들은 노래가 없어요")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                VStack(spacing: 0) {
                    ForEach(vm.recentSongs.prefix(5)) { song in
                        MyRecentSongRow(song: song, artworkURL: vm.recentSongArtworkURLs[song.id])
                    }
                }
            }
        }
    }

    private var recentRunsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 러닝")
                .font(.system(size: 18, weight: .bold))
            if vm.recentRuns.isEmpty && !vm.isLoading {
                Text("최근 러닝이 없어요")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(vm.recentRuns.prefix(5)) { run in
                    NavigationLink { RunActivityDetailView(record: run) } label: {
                        MyProfileRecentRunRow(run: run)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )
    }

    private func refreshAfterEdit() {
        myViewModel.loadData()
        Task { await vm.load() }
    }
}

private struct ProfileStatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MyRecentSongRow: View {
    let song: FriendRecentSong
    let artworkURL: String?

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(song.artistName.isEmpty ? "Apple Music" : song.artistName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let playedAtText {
                Text(playedAtText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.gray500)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var artwork: some View {
        Group {
            if let artworkData = song.artworkData, let data = Data(base64Encoded: artworkData), let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                RemoteArtworkView(urlString: artworkURL ?? song.artworkURL)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var playedAtText: String? {
        guard let playedAt = song.playedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: playedAt, relativeTo: Date())
    }
}

private struct MyProfileRecentRunRow: View {
    let run: RunRecord
    var body: some View {
        HStack(spacing: 12) {
            RunRouteThumbnailView(coordinates: run.routeCoordinates).frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(run.startedAt.formatted(.dateTime.month().day().weekday()))
                    .font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                Text(String(format: "%.1f km · %d분", run.distance, run.duration / 60))
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.textPrimary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Color.gray400)
        }
        .padding(12).background(Color.white.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
