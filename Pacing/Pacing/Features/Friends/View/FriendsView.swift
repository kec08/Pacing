import SwiftUI

struct FriendsView: View {
    @StateObject private var vm = FriendsViewModel()
    @State private var showsRequests = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    headerSection
                    searchSection
                    if vm.hasSearchQuery {
                        searchResultsSection
                    } else {
                        friendsSection
                        recommendationsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.backgroundSecondary)
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("친구")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("러닝 메이트와 음악으로 이어져요")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Button {
                showsRequests = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 44, height: 44)

                    if !vm.incomingRequests.isEmpty {
                        Text("\(min(vm.incomingRequests.count, 9))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 17, height: 17)
                            .background(Color.accent500)
                            .clipShape(Circle())
                            .offset(x: 1, y: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("받은 친구 요청")
        }
    }

    private var searchSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.gray500)

            TextField("닉네임 검색", text: $vm.searchText)
                .focused($isSearchFocused)
                .font(.system(size: 15))
                .foregroundStyle(Color.textPrimary)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit {
                    Task { await vm.search() }
                }

            if vm.isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if vm.hasSearchQuery {
                Button {
                    vm.clearSearch()
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.gray400)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                cardStack {
                    ForEach(vm.searchResults) { user in
                        FriendCandidateRow(user: user, buttonTitle: vm.buttonTitle(for: user), isEnabled: vm.canSendRequest(to: user)) {
                            Task { await vm.sendRequest(to: user) }
                        }
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
                cardStack {
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
                cardStack {
                    ForEach(vm.recommendedUsers) { user in
                        FriendCandidateRow(user: user, buttonTitle: vm.buttonTitle(for: user), isEnabled: vm.canSendRequest(to: user)) {
                            Task { await vm.sendRequest(to: user) }
                        }
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
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            content()
        }
    }

    private func cardStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    requestsContent
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.backgroundSecondary)
            .refreshable { await vm.load() }
            .navigationBarHidden(true)
        }
        .task { await vm.load() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("친구 요청")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("받은 요청을 확인하고 수락하거나 취소할 수 있어요")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
        }
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
            .background(Color.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
            .background(Color.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            VStack(spacing: 0) {
                ForEach(vm.incomingRequests) { request in
                    FriendRequestRow(request: request) {
                        Task { await vm.accept(request) }
                    } onReject: {
                        Task { await vm.reject(request) }
                    }
                }
            }
            .background(Color.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("친구 요청을 보냈어요")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 8)

            Button(action: onReject) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.gray600)
                    .frame(width: 34, height: 34)
                    .background(Color.gray100)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button(action: onAccept) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.main500)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 68)
        }
    }
}

private struct FriendUserRow: View {
    let user: FriendUser

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatar(user: user)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.nickname)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(user.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Image(systemName: "music.note")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.main500)
                .frame(width: 34, height: 34)
                .background(Color.main200.opacity(0.45))
                .clipShape(Circle())
        }
        .padding(14)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 68)
        }
    }
}

private struct FriendCandidateRow: View {
    let user: FriendUser
    let buttonTitle: String
    let isEnabled: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatar(user: user)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.nickname)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(user.source.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.sub500)
            }

            Spacer(minLength: 8)

            Button(action: onSend) {
                Text(buttonTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isEnabled ? .white : Color.gray500)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(isEnabled ? Color.main500 : Color.gray100)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        }
        .padding(14)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 68)
        }
    }
}

private struct FriendAvatar: View {
    let user: FriendUser

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.main200.opacity(0.55))
            Text(user.initials)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.main500)
        }
        .frame(width: 44, height: 44)
    }
}
