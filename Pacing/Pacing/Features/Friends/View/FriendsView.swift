import SwiftUI
import UIKit

struct FriendsView: View {
    @StateObject private var vm = FriendsViewModel()
    @State private var showsRequests = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                screenBackground

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        headerSection
                        searchSection
                        if vm.hasSearchQuery {
                            searchResultsSection
                        } else {
                            friendsSection
                            recommendationsSection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }
            .refreshable { await vm.load() }
            .navigationBarHidden(true)
        }
        .task { await vm.load() }
        .fullScreenCover(isPresented: $showsRequests) {
            FriendRequestsFullScreenView(vm: vm, isPresented: $showsRequests)
        }
        .alert("친구 탭 오류", isPresented: errorBinding) {
            Button("확인", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var headerSection: some View {
        ZStack {
            Text("친구")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                GlassIconButton(action: { showsRequests = true }) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.textPrimary.opacity(0.9))
                }
                .overlay(alignment: .topTrailing) {
                    if !vm.incomingRequests.isEmpty {
                        Circle()
                            .fill(Color.main500)
                            .frame(width: 16, height: 16)
                            .overlay {
                                Text("\(min(vm.incomingRequests.count, 9))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .offset(x: 1, y: 1)
                    }
                }
                .accessibilityLabel("받은 친구 요청")
            }
        }
        .frame(height: 54)
    }

    private var screenBackground: some View {
        LinearGradient(
            colors: [
                Color.main200.opacity(0.4),
                Color.backgroundSecondary,
                Color.backgroundPrimary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var searchSection: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.gray500)

                TextField("검색", text: $vm.searchText)
                    .focused($isSearchFocused)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await vm.search() }
                    }

                if vm.isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .glassCapsule()

            if vm.hasSearchQuery {
                Button {
                    vm.clearSearch()
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary.opacity(0.72))
                        .frame(width: 46, height: 46)
                        .glassCircle()
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: vm.searchText) { _, newValue in
            guard newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            vm.searchResults = []
        }
    }

    private var searchResultsSection: some View {
        section("검색 결과") {
            if vm.searchResults.isEmpty {
                emptyCard(vm.isSearching ? "검색 중이에요" : "검색 결과가 없어요")
            } else {
                listStack(spacing: 12) {
                    ForEach(vm.searchResults) { user in
                        FriendCandidateRow(
                            user: user,
                            buttonTitle: vm.buttonTitle(for: user),
                            isEnabled: vm.canSendRequest(to: user),
                            relationship: relationship(for: user),
                                onSend: { Task { await vm.sendRequest(to: user) } },
                                onRequestSent: { vm.markRequestSent(to: user) },
                                onRequestCanceled: { vm.markRequestCanceled(to: user) },
                                onDismiss: { vm.dismissSearchResult(user) }
                            )
                        }
                }
            }
        }
    }

    private var friendsSection: some View {
        section("친구") {
            if vm.isLoading && vm.friends.isEmpty {
                loadingCard
            } else if vm.friends.isEmpty {
                emptyFriendsState
            } else {
                listStack(spacing: 12) {
                    ForEach(vm.friends) { friend in
                        NavigationLink {
                            FriendProfileView(friend: friend, initialRelationship: .friend)
                        } label: {
                            FriendUserRow(user: friend)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("추천 친구")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
            }

            if vm.isLoading && vm.recommendedUsers.isEmpty {
                loadingCard
            } else if vm.recommendedUsers.isEmpty {
                emptyCard("추천할 러너를 찾는 중이에요")
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(vm.recommendedUsers) { user in
                            FriendRecommendationCard(
                                user: user,
                                buttonTitle: vm.buttonTitle(for: user),
                                isEnabled: vm.canSendRequest(to: user),
                                relationship: relationship(for: user),
                                onSend: { Task { await vm.sendRequest(to: user) } },
                                onRequestSent: { vm.markRequestSent(to: user) },
                                onRequestCanceled: { vm.markRequestCanceled(to: user) },
                                onDismiss: { vm.dismissRecommendation(user) }
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("불러오는 중")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassRounded(cornerRadius: 16)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            content()
        }
    }

    private func listStack<Content: View>(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: spacing) {
            content()
        }
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(Color.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassRounded(cornerRadius: 16)
    }

    private var emptyFriendsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.gray500)

            VStack(spacing: 4) {
                Text("친구가 없습니다")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("추천 친구를 통해 친구를 추가해보세요")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )
    }

    private func relationship(for user: FriendUser) -> FriendRelationship {
        vm.sentRequestUIDs.contains(user.id) ? .requestPending : .none
    }
}

private struct FriendRequestsFullScreenView: View {
    @ObservedObject var vm: FriendsViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                requestBackground

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 18)
                        .padding(.top, 10)

                    if vm.isLoading && vm.incomingRequests.isEmpty {
                        loadingRequestsState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.incomingRequests.isEmpty {
                        emptyRequestsState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            requestsContent
                                .padding(.horizontal, 18)
                                .padding(.top, 18)
                                .padding(.bottom, 34)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .refreshable { await vm.load() }
            .navigationBarHidden(true)
        }
        .task { await vm.load() }
    }

    private var requestBackground: some View {
        LinearGradient(
            colors: [
                Color.main200.opacity(0.4),
                Color.backgroundSecondary,
                Color.backgroundPrimary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        ZStack {
            Text("친구 요청")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                GlassIconButton(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary.opacity(0.72))
                }
                .accessibilityLabel("닫기")
            }
        }
        .frame(height: 54)
    }

    private var loadingRequestsState: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("요청을 불러오는 중")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.bottom, 54)
    }

    private var emptyRequestsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.gray500)
            Text("새로운 친구 요청이 없어요")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text("요청이 도착하면 이 화면에서 확인할 수 있어요")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.bottom, 54)
    }

    private var requestsContent: some View {
        VStack(spacing: 12) {
            ForEach(vm.incomingRequests) { request in
                FriendRequestRow(request: request) {
                    Task { await vm.accept(request) }
                } onReject: {
                    Task { await vm.reject(request) }
                }
            }
        }
    }
}

private struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            FriendAvatar(user: request.sender)

            VStack(alignment: .leading, spacing: 3) {
                Text(request.sender.nickname)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("친구 요청을 보냈어요")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 8)

            Button(action: onReject) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textPrimary.opacity(0.62))
                    .frame(width: 34, height: 34)
                    .glassCircle()
            }
            .buttonStyle(.plain)

            Button(action: onAccept) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.main500)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

private struct FriendUserRow: View {
    let user: FriendUser

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatar(user: user)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.nickname)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(user.statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Image(systemName: "music.note")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.main500)
                .frame(width: 34, height: 34)
                .glassCircle(tint: Color.main500.opacity(0.12))
        }
        .padding(.vertical, 2)
    }
}

private struct FriendCandidateRow: View {
    let user: FriendUser
    let buttonTitle: String
    let isEnabled: Bool
    let relationship: FriendRelationship
    let onSend: () -> Void
    let onRequestSent: () -> Void
    let onRequestCanceled: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                FriendProfileView(
                    friend: user,
                    initialRelationship: relationship,
                    onRequestSent: { _ in onRequestSent() },
                    onRequestCanceled: { _ in onRequestCanceled() }
                )
            } label: {
                HStack(spacing: 12) {
                    FriendAvatar(user: user)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(user.nickname)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text(user.source.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button(action: onSend) {
                Text(buttonTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isEnabled ? Color.main500 : Color.gray500)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .glassCapsule(tint: isEnabled ? Color.main500.opacity(0.13) : Color.gray100.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary.opacity(0.46))
                    .frame(width: 28, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

private struct FriendRecommendationCard: View {
    let user: FriendUser
    let buttonTitle: String
    let isEnabled: Bool
    let relationship: FriendRelationship
    let onSend: () -> Void
    let onRequestSent: () -> Void
    let onRequestCanceled: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                NavigationLink {
                    FriendProfileView(
                        friend: user,
                        initialRelationship: relationship,
                        onRequestSent: { _ in onRequestSent() },
                        onRequestCanceled: { _ in onRequestCanceled() }
                    )
                } label: {
                    FriendAvatar(user: user, size: 44, fontSize: 18)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary.opacity(0.42))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                FriendProfileView(
                    friend: user,
                    initialRelationship: relationship,
                    onRequestSent: { _ in onRequestSent() },
                    onRequestCanceled: { _ in onRequestCanceled() }
                )
            } label: {
                Text(user.nickname)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.plain)

            Button(action: onSend) {
                Text(buttonTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isEnabled ? Color.main500 : Color.gray500)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .glassCapsule(tint: isEnabled ? Color.main500.opacity(0.13) : Color.gray100.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        }
        .frame(width: 122)
        .padding(12)
        .glassRounded(cornerRadius: 16)
    }
}

private struct FriendAvatar: View {
    let user: FriendUser
    var size: CGFloat = 48
    var fontSize: CGFloat = 18

    var body: some View {
        ZStack {
            if let image = user.profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.main200.opacity(0.9), Color.main300.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(user.initials)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(Color.main500)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(.white.opacity(0.85), lineWidth: 1.5)
        }
        .shadow(color: Color.main500.opacity(0.1), radius: 8, y: 4)
    }
}

private struct GlassIconButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .frame(width: 44, height: 44)
                .glassCircle()
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func glassCapsule(tint: Color = Color.backgroundPrimary.opacity(0.58)) -> some View {
        background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(tint)
                }
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: Color.main500.opacity(0.07), radius: 10, y: 6)
        }
    }

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

    func glassRounded(cornerRadius: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.backgroundPrimary.opacity(0.58))
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
    var profileImage: UIImage? {
        guard
            let profileImageBase64,
            let data = Data(base64Encoded: profileImageBase64)
        else { return nil }

        return UIImage(data: data)
    }
}
