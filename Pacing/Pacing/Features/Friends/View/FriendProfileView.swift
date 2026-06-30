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
                    statsSection
                    recentSongsSection
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

                Text(vm.friend.statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            if vm.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 4)
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
            .glassRounded(cornerRadius: 16, tint: relationshipTint)
        }
        .buttonStyle(.plain)
        .disabled(!vm.canTapAction)
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
            return Color.main500.opacity(0.12)
        case .requestPending:
            return Color.gray100.opacity(0.82)
        case .none:
            return Color.main500.opacity(0.13)
        }
    }

    private var statsSection: some View {
        HStack(spacing: 0) {
            FriendProfileStatItem(title: "누적 거리", value: vm.formattedTotalDistance)
            statDivider
            FriendProfileStatItem(title: "운동 시간", value: vm.formattedTotalDuration)
            statDivider
            FriendProfileStatItem(title: "평균 페이스", value: vm.formattedAveragePace)
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

            if vm.recentSongs.isEmpty {
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
                    ForEach(vm.recentSongs) { song in
                        FriendRecentSongRow(song: song)
                    }
                }
                .glassRounded(cornerRadius: 16)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )
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
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.main500)
                .frame(width: 36, height: 36)
                .glassCircle(tint: Color.main500.opacity(0.12))

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
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 62)
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
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: Color.main500.opacity(0.07), radius: 10, y: 6)
        }
    }

    func glassRounded(
        cornerRadius: CGFloat,
        tint: Color = Color.backgroundPrimary.opacity(0.58)
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
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
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
