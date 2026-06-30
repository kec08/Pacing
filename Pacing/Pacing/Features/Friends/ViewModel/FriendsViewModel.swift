import Foundation
import FirebaseAuth

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [FriendUser] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var recommendedUsers: [FriendUser] = []
    @Published var searchText: String = ""
    @Published var searchResults: [FriendUser] = []
    @Published var sentRequestUIDs: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?

    private let service = FirestoreService.shared

    var currentUID: String? {
        Auth.auth().currentUser?.uid
    }

    var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var excludedUIDs: Set<String> {
        Set(friends.map(\.id))
            .union(incomingRequests.map(\.fromUID))
            .union(sentRequestUIDs)
    }

    func load() async {
        guard let uid = currentUID else {
            errorMessage = "로그인이 필요해요."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let friendsTask = service.fetchFriends(uid: uid)
            async let requestsTask = service.fetchIncomingFriendRequests(uid: uid)

            let loadedFriends = try await friendsTask
            let loadedRequests = try await requestsTask

            friends = loadedFriends
            incomingRequests = loadedRequests
            recommendedUsers = try await service.fetchRecommendedUsers(
                currentUID: uid,
                excluding: excludedUIDs
            )

            if hasSearchQuery {
                await search()
            }
        } catch {
            errorMessage = "친구 정보를 불러오지 못했어요."
        }

        isLoading = false
    }

    func search() async {
        guard let uid = currentUID else {
            searchResults = []
            return
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            searchResults = try await service.searchUsersByNickname(
                currentUID: uid,
                query: query,
                excluding: excludedUIDs
            )
        } catch {
            searchResults = []
            errorMessage = "검색 결과를 불러오지 못했어요."
        }

        isSearching = false
    }

    func clearSearch() {
        searchText = ""
        searchResults = []
    }

    func sendRequest(to user: FriendUser) async {
        guard let uid = currentUID else { return }

        errorMessage = nil
        do {
            try await service.sendFriendRequest(from: uid, to: user.id)
            sentRequestUIDs.insert(user.id)
            searchResults.removeAll { $0.id == user.id }
            recommendedUsers.removeAll { $0.id == user.id }
        } catch {
            errorMessage = "친구 요청을 보내지 못했어요."
        }
    }

    func accept(_ request: FriendRequest) async {
        let nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"

        errorMessage = nil
        do {
            try await service.acceptFriendRequest(request, currentUserNickname: nickname)
            incomingRequests.removeAll { $0.id == request.id }
            await load()
        } catch {
            errorMessage = "친구 요청을 수락하지 못했어요."
        }
    }

    func reject(_ request: FriendRequest) async {
        errorMessage = nil
        do {
            try await service.rejectFriendRequest(request.id)
            incomingRequests.removeAll { $0.id == request.id }
            recommendedUsers = try await refreshedRecommendations()
        } catch {
            errorMessage = "친구 요청을 거절하지 못했어요."
        }
    }

    private func refreshedRecommendations() async throws -> [FriendUser] {
        guard let uid = currentUID else { return [] }
        return try await service.fetchRecommendedUsers(
            currentUID: uid,
            excluding: excludedUIDs
        )
    }

    func buttonTitle(for user: FriendUser) -> String {
        sentRequestUIDs.contains(user.id) ? "요청됨" : "친구 추가"
    }

    func canSendRequest(to user: FriendUser) -> Bool {
        !sentRequestUIDs.contains(user.id)
    }
}
