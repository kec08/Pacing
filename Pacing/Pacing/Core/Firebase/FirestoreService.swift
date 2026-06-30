import Foundation
import FirebaseFirestore
import CoreLocation

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - 프로필 저장
    func saveUserProfile(uid: String, nickname: String, height: Int, weight: Int, age: Int, profileImageBase64: String? = nil) async throws {
        var data: [String: Any] = [
            "nickname": nickname,
            "height": height,
            "weight": weight,
            "age": age,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let img = profileImageBase64 {
            data["profileImageBase64"] = img
        }
        try await db.collection("users").document(uid).setData(data, merge: true)
    }

    // MARK: - 프로필 조회
    func fetchUserProfile(uid: String) async throws -> [String: Any] {
        let doc = try await db.collection("users").document(uid).getDocument()
        return doc.data() ?? [:]
    }

    // MARK: - 프로필 존재 여부 (로그인 후 재입력 방지)
    func hasUserProfile(uid: String) async -> Bool {
        guard let doc = try? await db.collection("users").document(uid).getDocument(),
              doc.exists,
              let nickname = doc.data()?["nickname"] as? String,
              !nickname.trimmingCharacters(in: .whitespaces).isEmpty
        else { return false }
        return true
    }

    // MARK: - 러닝기록 저장
    func saveRunRecord(uid: String, record: RunRecord) async throws {
        var data: [String: Any] = [
            "startedAt": Timestamp(date: record.startedAt),
            "duration": record.duration,
            "distance": record.distance,
            "avgPace": record.avgPace
        ]
        let geoPoints = record.routeCoordinates.map {
            GeoPoint(latitude: $0.latitude, longitude: $0.longitude)
        }
        data["routeCoordinates"] = geoPoints

        try await db.collection("users").document(uid)
            .collection("runHistory").document(record.id)
            .setData(data)
    }

    // MARK: - 러닝기록 조회
    func fetchRunHistory(uid: String, limit: Int = 10) async throws -> [RunRecord] {
        let snapshot = try await db.collection("users").document(uid)
            .collection("runHistory")
            .order(by: "startedAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> RunRecord? in
            let d = doc.data()
            guard let ts = d["startedAt"] as? Timestamp else { return nil }

            // Firestore는 정수값을 Int64로 저장하므로 NSNumber로 통일해서 읽기
            let duration = (d["duration"] as? NSNumber)?.intValue ?? 0
            let distance = (d["distance"] as? NSNumber)?.doubleValue ?? 0
            let avgPace  = (d["avgPace"]  as? NSNumber)?.doubleValue ?? 0

            let geoPoints = (d["routeCoordinates"] as? [GeoPoint]) ?? []
            let coords = geoPoints.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }

            return RunRecord(
                id: doc.documentID,
                startedAt: ts.dateValue(),
                duration: duration,
                distance: distance,
                avgPace: avgPace,
                routeCoordinates: coords
            )
        }
    }

    // MARK: - 친구 목록 조회
    func fetchFriends(uid: String) async throws -> [FriendUser] {
        let snapshot = try await db.collection("users").document(uid)
            .collection("friends")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.map { doc in
            let data = doc.data()
            return FriendUser(
                id: doc.documentID,
                nickname: data["nickname"] as? String ?? "러너",
                profileImageBase64: data["profileImageBase64"] as? String,
                statusText: data["statusText"] as? String ?? "최근 활동 없음",
                source: .friend
            )
        }
    }

    // MARK: - 받은 친구 요청 조회
    func fetchIncomingFriendRequests(uid: String) async throws -> [FriendRequest] {
        let snapshot = try await db.collection("friendRequests")
            .whereField("toUID", isEqualTo: uid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        var requests: [FriendRequest] = []
        for doc in snapshot.documents {
            let data = doc.data()
            guard let fromUID = data["fromUID"] as? String else { continue }
            let sender = try await fetchFriendUser(uid: fromUID, source: .request)
            requests.append(
                FriendRequest(
                    id: doc.documentID,
                    fromUID: fromUID,
                    toUID: data["toUID"] as? String ?? uid,
                    status: FriendRequestStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                    sender: sender
                )
            )
        }
        return requests
    }

    // MARK: - 닉네임 검색
    func searchUsersByNickname(
        currentUID: String,
        query: String,
        excluding excludedUIDs: Set<String>,
        limit: Int = 10
    ) async throws -> [FriendUser] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let snapshot = try await db.collection("users")
            .order(by: "nickname")
            .start(at: [trimmed])
            .end(at: [trimmed + "\u{f8ff}"])
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard doc.documentID != currentUID, !excludedUIDs.contains(doc.documentID) else { return nil }
            return makeFriendUser(from: doc, source: .search)
        }
    }

    // MARK: - 추천 친구 조회
    func fetchRecommendedUsers(
        currentUID: String,
        excluding excludedUIDs: Set<String>,
        limit: Int = 10
    ) async throws -> [FriendUser] {
        let snapshot = try await db.collection("users")
            .order(by: "createdAt", descending: true)
            .limit(to: limit + excludedUIDs.count + 1)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard doc.documentID != currentUID, !excludedUIDs.contains(doc.documentID) else { return nil }
            return makeFriendUser(from: doc, source: .recent)
        }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: - 친구 요청 생성
    func sendFriendRequest(from fromUID: String, to toUID: String) async throws {
        guard !fromUID.isEmpty, !toUID.isEmpty, fromUID != toUID else { return }

        let requestID = "\(fromUID)_\(toUID)"
        let data: [String: Any] = [
            "fromUID": fromUID,
            "toUID": toUID,
            "status": FriendRequestStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("friendRequests")
            .document(requestID)
            .setData(data, merge: true)
    }

    // MARK: - 친구 요청 수락
    func acceptFriendRequest(_ request: FriendRequest, currentUserNickname: String) async throws {
        let fromUser = request.sender
        let currentUser = try await fetchFriendUser(uid: request.toUID, source: .friend)

        let batch = db.batch()
        let requestRef = db.collection("friendRequests").document(request.id)
        let myFriendRef = db.collection("users").document(request.toUID)
            .collection("friends").document(request.fromUID)
        let senderFriendRef = db.collection("users").document(request.fromUID)
            .collection("friends").document(request.toUID)

        batch.setData(friendDocumentData(from: fromUser), forDocument: myFriendRef, merge: true)
        batch.setData(
            friendDocumentData(
                from: FriendUser(
                    id: currentUser.id,
                    nickname: currentUser.nickname.isEmpty ? currentUserNickname : currentUser.nickname,
                    profileImageBase64: currentUser.profileImageBase64,
                    statusText: currentUser.statusText,
                    source: .friend
                )
            ),
            forDocument: senderFriendRef,
            merge: true
        )
        batch.updateData(["status": FriendRequestStatus.accepted.rawValue], forDocument: requestRef)

        try await batch.commit()
    }

    // MARK: - 친구 요청 거절
    func rejectFriendRequest(_ requestID: String) async throws {
        try await db.collection("friendRequests")
            .document(requestID)
            .updateData(["status": FriendRequestStatus.rejected.rawValue])
    }

    private func fetchFriendUser(uid: String, source: FriendRecommendationSource) async throws -> FriendUser {
        let doc = try await db.collection("users").document(uid).getDocument()
        return makeFriendUser(from: doc, source: source) ?? FriendUser(
            id: uid,
            nickname: "러너",
            profileImageBase64: nil,
            statusText: "최근 활동 없음",
            source: source
        )
    }

    private func makeFriendUser(from doc: DocumentSnapshot, source: FriendRecommendationSource) -> FriendUser? {
        guard let data = doc.data(),
              let nickname = data["nickname"] as? String,
              !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        return FriendUser(
            id: doc.documentID,
            nickname: nickname,
            profileImageBase64: data["profileImageBase64"] as? String,
            statusText: data["statusText"] as? String ?? "최근 활동 없음",
            source: source
        )
    }

    private func friendDocumentData(from user: FriendUser) -> [String: Any] {
        var data: [String: Any] = [
            "uid": user.id,
            "nickname": user.nickname,
            "statusText": user.statusText,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let profileImageBase64 = user.profileImageBase64 {
            data["profileImageBase64"] = profileImageBase64
        }
        return data
    }
}
