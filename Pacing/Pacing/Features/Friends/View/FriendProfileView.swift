import SwiftUI
import UIKit

struct FriendProfileView: View {
    @StateObject private var vm: FriendProfileViewModel
    private let onRequestSent: ((FriendUser) -> Void)?
    private let onRequestCanceled: ((FriendUser) -> Void)?

    init(
        friend: FriendUser,
        initialRelationship: FriendRelationship = .friend,
        onRequestSent: ((FriendUser) -> Void)? = nil,
        onRequestCanceled: ((FriendUser) -> Void)? = nil
    ) {
        _vm = StateObject(
            wrappedValue: FriendProfileViewModel(
                friend: friend,
                initialRelationship: initialRelationship
            )
        )
        self.onRequestSent = onRequestSent
        self.onRequestCanceled = onRequestCanceled
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 24) {
                    profileHeader
                    relationshipAction
                    if vm.canViewDetails {
                        statsSection
                        recentRunsSection
                        recentSongsSection
                    } else {
                        privateProfileNotice
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("친구 프로필")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .alert("친구 프로필 오류", isPresented: errorBinding) {
            Button("확인", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var recentRunsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 러닝")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            if vm.isLoading && vm.recentRuns.isEmpty {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonRow()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                }
            } else if !vm.canViewActivity {
                privateActivityState(
                    systemImage: "lock.fill",
                    title: "친구가 되면 러닝을 볼 수 있어요",
                    description: "친구 요청을 수락하면 최근 러닝 기록이 여기에 표시돼요."
                )
            } else if vm.recentRuns.isEmpty {
                ContentUnavailableView(
                    "최근 러닝이 없어요",
                    systemImage: "figure.run",
                    description: Text("친구의 러닝 기록이 등록되면 여기에서 확인할 수 있어요."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.recentRuns) { run in
                        FriendProfileRecentRunRow(run: run)
                    }
                }
            }
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
            FriendProfileAvatar(user: vm.friend)

            VStack(spacing: 4) {
                Text(vm.friend.nickname)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                if vm.isLoading {
                    SkeletonBlock(width: 92, height: 13, cornerRadius: 7)
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

    private var relationshipAction: some View {
        Button {
            Task {
                switch vm.relationship {
                case .none:
                    let didSend = await vm.sendFriendRequest()
                    if didSend {
                        onRequestSent?(vm.friend)
                    }
                case .requestPending:
                    let didCancel = await vm.cancelFriendRequest()
                    if didCancel {
                        onRequestCanceled?(vm.friend)
                    }
                case .friend:
                    break
                }
            }
        } label: {
            HStack(spacing: 8) {
                if vm.isUpdatingRelationship {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: relationshipIcon)
                        .font(.system(size: 17, weight: .bold))
                }

                Text(vm.actionTitle)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(relationshipForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .glassRounded(
                cornerRadius: 16,
                tint: relationshipTint,
                stroke: relationshipBorder
            )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(vm.canTapAction)
        .animation(.easeInOut(duration: 0.2), value: vm.relationship)
    }

    private var relationshipIcon: String {
        switch vm.relationship {
        case .friend:
            return "person.2.fill"
        case .requestPending:
            return "clock.fill"
        case .none:
            return "person.badge.plus"
        }
    }

    private var relationshipForeground: Color {
        switch vm.relationship {
        case .friend:
            return Color.main500
        case .requestPending:
            return Color.textSecondary
        case .none:
            return Color.main500
        }
    }

    private var relationshipTint: Color {
        switch vm.relationship {
        case .friend:
            return Color.main500.opacity(0.10)
        case .requestPending:
            return Color.gray100.opacity(0.82)
        case .none:
            return Color.main500.opacity(0.13)
        }
    }

    private var relationshipBorder: Color {
        vm.relationship == .friend ? Color.main500.opacity(0.34) : Color.surfaceBorder
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
                    FriendProfileStatItem(title: "누적 거리", value: vm.formattedTotalDistance)
                    statDivider
                    FriendProfileStatItem(title: "운동 시간", value: vm.formattedTotalDuration)
                    statDivider
                    FriendProfileStatItem(title: "평균 페이스", value: vm.formattedAveragePace)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var privateProfileNotice: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            Text("비공개 프로필입니다")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("이 친구가 프로필을 비공개로 설정했어요.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
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
            } else if !vm.canViewActivity {
                privateActivityState(
                    systemImage: "lock.fill",
                    title: "친구가 되면 음악을 볼 수 있어요",
                    description: "친구 요청을 수락하면 최근 들은 노래가 여기에 표시돼요."
                )
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
                        FriendRecentSongRow(
                            song: song,
                            artworkURL: vm.recentSongArtworkURLs[song.id],
                            isPlaying: vm.playingSongID == song.id,
                            playbackError: vm.playingSongID == song.id ? vm.playbackError : nil,
                            onPlay: { Task { await vm.playRecentSong(song) } }
                        )
                    }
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

    private func privateActivityState(
        systemImage: String,
        title: String,
        description: String
    ) -> some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct FriendProfileAvatar: View {
    let user: FriendUser

    var body: some View {
        ZStack {
            if let image = user.profileUIImage {
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
                Text(user.initials)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.main500)
            }
        }
        .frame(width: 104, height: 104)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.surfaceBorder, lineWidth: 1.5)
        }
        .shadow(color: Color.main500.opacity(0.12), radius: 14, y: 8)
    }
}

private struct FriendProfileStatItem: View {
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

private struct FriendRecentSongRow: View {
    let song: FriendRecentSong
    let artworkURL: String?
    let isPlaying: Bool
    let playbackError: String?
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                ZStack {
                    albumArtwork

                    if isPlaying {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.black.opacity(0.42))
                        FriendSongPlayingWaveform()
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(playbackError ?? (song.artistName.isEmpty ? "Apple Music" : song.artistName))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(playbackError == nil ? Color.textSecondary : Color.accent500)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(song.title) 재생")
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 62)
        }
    }

    private var albumArtwork: some View {
        Group {
            if let artworkData = song.artworkData,
               let data = Data(base64Encoded: artworkData),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if artworkURL != nil || song.artworkURL != nil {
                RemoteArtworkView(urlString: artworkURL ?? song.artworkURL)
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.main200.opacity(0.32))

            Image(systemName: "music.note")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.main500)
        }
    }

    private var playedAtText: String? {
        guard let playedAt = song.playedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: playedAt, relativeTo: Date())
    }
}

private struct FriendSongPlayingWaveform: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 2.5) {
            waveBar(height: 16, delay: 0.0)
            waveBar(height: 23, delay: 0.1)
            waveBar(height: 14, delay: 0.2)
            waveBar(height: 20, delay: 0.3)
        }
        .frame(width: 30, height: 28)
        .onAppear { isAnimating = true }
        .accessibilityLabel("재생 중")
    }

    private func waveBar(height: CGFloat, delay: Double) -> some View {
        Capsule()
            .fill(.white)
            .frame(width: 2.5, height: height)
            .scaleEffect(y: isAnimating ? 0.52 : 1, anchor: .center)
            .animation(
                .easeInOut(duration: 0.52)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
    }
}

private struct FriendProfileRecentRunRow: View {
    let run: RunRecord

    var body: some View {
        NavigationLink {
            RunActivityDetailView(record: run)
        } label: {
            HStack(spacing: 14) {
                RunRouteThumbnailView(coordinates: run.routeCoordinates)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(run.startedAt))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)

                    HStack(spacing: 10) {
                        Label(formattedDistance(run.distance), systemImage: "figure.run")
                        Text(formattedDuration(run.duration))
                        Text(formattedPace(run.displayPace) + "/km")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.gray300)
            }
            .padding(14)
            .background(Color.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("친구의 러닝 활동 상세를 엽니다")
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
    }

    private func formattedDistance(_ distance: Double) -> String {
        String(format: "%.1f km", distance)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? String(format: "%d:%02d", hours, minutes) : "\(minutes)분"
    }

    private func formattedPace(_ pace: Double) -> String {
        RunRecord.formattedPace(pace)
    }
}

private extension View {
    func glassCircle(tint: Color = Color.backgroundPrimary.opacity(0.58)) -> some View {
        background {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .fill(tint)
                }
                .overlay {
                    Circle()
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                }
                .shadow(color: Color.main500.opacity(0.07), radius: 10, y: 6)
        }
    }

    func glassRounded(
        cornerRadius: CGFloat,
        tint: Color = Color.backgroundPrimary.opacity(0.58),
        stroke: Color = Color.surfaceBorder
    ) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                }
                .shadow(color: Color.main500.opacity(0.07), radius: 10, y: 6)
        }
    }
}

private extension FriendUser {
    var profileUIImage: UIImage? {
        guard
            let profileImageBase64,
            let data = Data(base64Encoded: profileImageBase64)
        else { return nil }

        return UIImage(data: data)
    }
}
