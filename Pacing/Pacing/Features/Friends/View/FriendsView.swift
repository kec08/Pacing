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
                    LazyVStack(alignment: .leading, spacing: 26) {
                        headerSection
                        searchSection
                        if vm.hasSearchQuery {
                            searchResultsSection
                        } else {
                            recommendationsSection
                            friendsSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
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
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                GlassIconButton(action: { showsRequests = true }) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Color.textPrimary.opacity(0.9))
                }
                .overlay(alignment: .topTrailing) {
                    if !vm.incomingRequests.isEmpty {
                        Circle()
                            .fill(Color.main500)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Text("\(min(vm.incomingRequests.count, 9))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .offset(x: 1, y: 1)
                    }
                }
                .accessibilityLabel("받은 친구 요청")
            }
        }
        .frame(height: 70)
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
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.gray500)

                TextField("검색", text: $vm.searchText)
                    .focused($isSearchFocused)
                    .font(.system(size: 18, weight: .medium))
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
            .padding(.horizontal, 18)
            .frame(height: 58)
            .glassCapsule()

            if vm.hasSearchQuery {
                Button {
                    vm.clearSearch()
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.textPrimary.opacity(0.72))
                        .frame(width: 58, height: 58)
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
                listStack {
                    ForEach(vm.searchResults) { user in
                        FriendCandidateRow(
                            user: user,
                            buttonTitle: vm.buttonTitle(for: user),
                            isEnabled: vm.canSendRequest(to: user),
                            onSend: { Task { await vm.sendRequest(to: user) } },
                            onDismiss: { vm.dismissSearchResult(user) }
                        )
                    }
                }
            }
        }
    }

    private var friendsSection: some View {
        section("내 친구") {
            if vm.isLoading && vm.friends.isEmpty {
                loadingCard
            } else if vm.friends.isEmpty {
                emptyCard("아직 친구가 없어요")
            } else {
                listStack {
                    ForEach(vm.friends) { friend in
                        FriendUserRow(user: friend)
                    }
                }
            }
        }
    }

    private var recommendationsSection: some View {
        section("추천 친구") {
            if vm.isLoading && vm.recommendedUsers.isEmpty {
                loadingCard
            } else if vm.recommendedUsers.isEmpty {
                emptyCard("추천할 러너를 찾는 중이에요")
            } else {
                listStack {
                    ForEach(vm.recommendedUsers) { user in
                        FriendCandidateRow(
                            user: user,
                            buttonTitle: vm.buttonTitle(for: user),
                            isEnabled: vm.canSendRequest(to: user),
                            onSend: { Task { await vm.sendRequest(to: user) } },
                            onDismiss: { vm.dismissRecommendation(user) }
                        )
                    }
                }
            }
        }
        .padding(.bottom, 16)
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
        .padding(.vertical, 24)
        .glassRounded(cornerRadius: 20)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            content()
        }
    }

    private func listStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 18) {
            content()
        }
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(Color.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassRounded(cornerRadius: 20)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )
    }
}

private struct FriendRequestsFullScreenView: View {
    @ObservedObject var vm: FriendsViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
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

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        header
                        requestsContent
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }
            .refreshable { await vm.load() }
            .navigationBarHidden(true)
        }
        .task { await vm.load() }
    }

    private var header: some View {
        ZStack {
            Text("친구 요청")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                GlassIconButton(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.textPrimary.opacity(0.72))
                }
                .accessibilityLabel("닫기")
            }
        }
        .frame(height: 70)
    }

    @ViewBuilder
    private var requestsContent: some View {
        if vm.isLoading && vm.incomingRequests.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("요청을 불러오는 중")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .glassRounded(cornerRadius: 20)
        } else if vm.incomingRequests.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "person.2")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.gray500)
                Text("새로운 친구 요청이 없어요")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("요청이 도착하면 이 화면에서 확인할 수 있어요")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .padding(.horizontal, 20)
            .glassRounded(cornerRadius: 20)
        } else {
            VStack(spacing: 18) {
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
}

private struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatar(user: request.sender)

            VStack(alignment: .leading, spacing: 4) {
                Text(request.sender.nickname)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("친구 요청을 보냈어요")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 8)

            Button(action: onReject) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textPrimary.opacity(0.62))
                    .frame(width: 40, height: 40)
                    .glassCircle()
            }
            .buttonStyle(.plain)

            Button(action: onAccept) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
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
        HStack(spacing: 14) {
            FriendAvatar(user: user)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.nickname)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(user.handleText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Image(systemName: "music.note")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.main500)
                .frame(width: 42, height: 42)
                .glassCircle(tint: Color.main500.opacity(0.12))
        }
        .padding(.vertical, 2)
    }
}

private struct FriendCandidateRow: View {
    let user: FriendUser
    let buttonTitle: String
    let isEnabled: Bool
    let onSend: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            FriendAvatar(user: user)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.nickname)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(user.handleText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 8)

            Button(action: onSend) {
                Text(buttonTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isEnabled ? Color.main500 : Color.gray500)
                    .padding(.horizontal, 22)
                    .frame(height: 44)
                    .glassCapsule(tint: isEnabled ? Color.main500.opacity(0.13) : Color.gray100.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.textPrimary.opacity(0.46))
                    .frame(width: 34, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

private struct FriendAvatar: View {
    let user: FriendUser

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
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(Color.main500)
            }
        }
        .frame(width: 66, height: 66)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(.white.opacity(0.85), lineWidth: 2)
        }
        .shadow(color: Color.main500.opacity(0.12), radius: 12, y: 5)
    }
}

private struct GlassIconButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .frame(width: 58, height: 58)
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
                .shadow(color: Color.main500.opacity(0.08), radius: 14, y: 8)
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
                .shadow(color: Color.main500.opacity(0.08), radius: 14, y: 8)
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
                .shadow(color: Color.main500.opacity(0.08), radius: 14, y: 8)
        }
    }
}

private extension FriendUser {
    var handleText: String {
        let prefix = id.prefix(8)
        return "@\(prefix)"
    }

    var profileImage: UIImage? {
        guard
            let profileImageBase64,
            let data = Data(base64Encoded: profileImageBase64)
        else { return nil }

        return UIImage(data: data)
    }
}
