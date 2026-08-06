import Foundation
import FirebaseFirestore
import FirebaseFunctions
import CoreLocation

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "asia-northeast3")

    private init() {}

    // MARK: - 프로필 저장
    func saveUserProfile(uid: String, nickname: String, height: Int, weight: Int, profileImageBase64: String? = nil) async throws {
        var data: [String: Any] = [
            "nickname": nickname,
            "height": height,
            "weight": weight,
            // 심사 대응: 더 이상 수집하지 않는 기존 나이 필드를 함께 정리한다.
            "age": FieldValue.delete(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let img = profileImageBase64 {
            data["profileImageBase64"] = img
        }
        try await db.collection("users").document(uid).setData(data, merge: true)
    }

    func removeLegacyAge(uid: String) async throws {
        try await db.collection("users").document(uid).updateData([
            "age": FieldValue.delete()
        ])
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
        data["lapPaces"] = record.lapPaces.map {
            ["kilometer": $0.kilometer, "pace": $0.pace]
        }

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
            let lapPaces = ((d["lapPaces"] as? [[String: Any]]) ?? []).compactMap { lap -> RunLapPace? in
                guard let kilometer = (lap["kilometer"] as? NSNumber)?.intValue,
                      let pace = (lap["pace"] as? NSNumber)?.doubleValue,
                      kilometer > 0,
                      pace > 0 else {
                    return nil
                }
                return RunLapPace(kilometer: kilometer, pace: pace)
            }

            return RunRecord(
                id: doc.documentID,
                startedAt: ts.dateValue(),
                duration: duration,
                distance: distance,
                avgPace: avgPace,
                routeCoordinates: coords,
                lapPaces: lapPaces
            )
        }
    }

    // MARK: - 친구 프로필 통계 조회
    func fetchFriendProfileStats(uid: String) async throws -> FriendProfileStats {
        let records = try await fetchRunHistory(uid: uid, limit: 100)
        guard !records.isEmpty else { return .empty }

        let totalDistance = records.reduce(0) { $0 + $1.distance }
        let totalDuration = records.reduce(0) { $0 + $1.duration }
        let averagePace = totalDistance > 0
            ? Double(totalDuration) / 60.0 / totalDistance
            : 0

        return FriendProfileStats(
            averagePace: averagePace,
            totalDuration: totalDuration,
            totalDistance: totalDistance,
            lastRunDate: records.first?.startedAt
        )
    }

    // MARK: - 마지막 러닝 날짜 조회
    private func fetchLastRunDate(uid: String) async throws -> Date? {
        let snapshot = try await db.collection("users").document(uid)
            .collection("runHistory")
            .order(by: "startedAt", descending: true)
            .limit(to: 1)
            .getDocuments()

        return (snapshot.documents.first?.data()["startedAt"] as? Timestamp)?.dateValue()
    }

    // MARK: - 최근 들은 노래 저장
    func saveRecentSong(
        uid: String,
        title: String,
        artistName: String,
        songStoreID: String?,
        artworkURL: String? = nil,
        artworkData: String? = nil
    ) async throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty, !trimmedTitle.isEmpty else { return }

        let documentID = songStoreID?.isEmpty == false ? songStoreID! : UUID().uuidString
        var data: [String: Any] = [
            "title": trimmedTitle,
            "artistName": artistName,
            "songStoreID": songStoreID ?? "",
            "playedAt": FieldValue.serverTimestamp()
        ]
        if let artworkURL, !artworkURL.isEmpty {
            data["artworkURL"] = artworkURL
        }
        if let artworkData, !artworkData.isEmpty {
            data["artworkData"] = artworkData
        }

        try await db.collection("users").document(uid)
            .collection("recentSongs").document(documentID)
            .setData(data, merge: true)
    }

    // MARK: - 최근 들은 노래 조회
    func fetchRecentSongs(uid: String, limit: Int = 10) async throws -> [FriendRecentSong] {
        let snapshot = try await db.collection("users").document(uid)
            .collection("recentSongs")
            .order(by: "playedAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let title = data["title"] as? String,
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }

            return FriendRecentSong(
                id: doc.documentID,
                title: title,
                artistName: data["artistName"] as? String ?? "",
                playedAt: (data["playedAt"] as? Timestamp)?.dateValue(),
                songStoreID: data["songStoreID"] as? String,
                artworkURL: data["artworkURL"] as? String,
                artworkData: data["artworkData"] as? String
            )
        }
    }

    // MARK: - 친구 최근 재생 음악 조회
    func fetchFriendsRecentSongs(
        currentUID: String,
        friendLimit: Int = 8,
        songsPerFriend: Int = 3
    ) async throws -> [FriendRecentSongActivity] {
        let snapshot = try await db.collection("users").document(currentUID)
            .collection("friends")
            .order(by: "createdAt", descending: true)
            .limit(to: friendLimit)
            .getDocuments()

        var activities: [FriendRecentSongActivity] = []
        for friendDocument in snapshot.documents {
            let nickname = friendDocument.data()["nickname"] as? String ?? "러너"
            let songs = try await fetchRecentSongs(
                uid: friendDocument.documentID,
                limit: max(1, songsPerFriend)
            )

            activities.append(
                contentsOf: songs.map { song in
                    FriendRecentSongActivity(
                        friendUID: friendDocument.documentID,
                        friendNickname: nickname,
                        song: song
                    )
                }
            )
        }

        return activities.sorted {
            ($0.song.playedAt ?? .distantPast) > ($1.song.playedAt ?? .distantPast)
        }
    }

    // MARK: - 친구 최근 러닝 조회
    func fetchFriendsRecentRuns(currentUID: String, friendLimit: Int = 8) async throws -> [FriendRecentRunActivity] {
        let snapshot = try await db.collection("users").document(currentUID)
            .collection("friends")
            .order(by: "createdAt", descending: true)
            .limit(to: friendLimit)
            .getDocuments()

        var activities: [FriendRecentRunActivity] = []
        for friendDocument in snapshot.documents {
            guard let run = try await fetchRunHistory(uid: friendDocument.documentID, limit: 1).first else {
                continue
            }

            let nickname = friendDocument.data()["nickname"] as? String ?? "러너"
            activities.append(
                FriendRecentRunActivity(
                    friendUID: friendDocument.documentID,
                    friendNickname: nickname,
                    run: run
                )
            )
        }

        return activities.sorted { $0.run.startedAt > $1.run.startedAt }
    }

    // MARK: - 친구 목록 조회
    func fetchFriends(uid: String) async throws -> [FriendUser] {
        let snapshot = try await db.collection("users").document(uid)
            .collection("friends")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        var friends: [FriendUser] = []
        for doc in snapshot.documents {
            let data = doc.data()
            let lastRunDate = try? await fetchLastRunDate(uid: doc.documentID)
            friends.append(FriendUser(
                id: doc.documentID,
                nickname: data["nickname"] as? String ?? "러너",
                profileImageBase64: data["profileImageBase64"] as? String,
                statusText: FriendActivityText.runningStatus(lastRunDate: lastRunDate),
                source: .friend
            ))
        }
        return friends
    }

    // MARK: - 친구 프로필 조회
    func fetchFriendUserProfile(uid: String, source: FriendRecommendationSource = .friend) async throws -> FriendUser {
        try await fetchFriendUser(uid: uid, source: source)
    }

    // MARK: - 보낸 친구 요청 조회
    func fetchPendingSentFriendRequestUIDs(uid: String) async throws -> Set<String> {
        let snapshot = try await db.collection("friendRequests")
            .whereField("fromUID", isEqualTo: uid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .getDocuments()

        return Set(snapshot.documents.compactMap { doc in
            doc.data()["toUID"] as? String
        })
    }

    // MARK: - 친구 관계 조회
    func fetchFriendRelationship(currentUID: String, targetUID: String) async throws -> FriendRelationship {
        guard !currentUID.isEmpty, !targetUID.isEmpty, currentUID != targetUID else {
            return .none
        }

        let friendDoc = try await db.collection("users").document(currentUID)
            .collection("friends").document(targetUID)
            .getDocument()

        if friendDoc.exists {
            return .friend
        }

        let requestDoc = try await db.collection("friendRequests")
            .document("\(currentUID)_\(targetUID)")
            .getDocument()

        if requestDoc.data()?["status"] as? String == FriendRequestStatus.pending.rawValue {
            return .requestPending
        }

        return .none
    }

    // MARK: - 받은 친구 요청 조회
    func fetchIncomingFriendRequests(uid: String) async throws -> [FriendRequest] {
        let snapshot = try await db.collection("friendRequests")
            .whereField("toUID", isEqualTo: uid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
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
        return requests.sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
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

        var users: [FriendUser] = []
        for doc in snapshot.documents {
            guard doc.documentID != currentUID, !excludedUIDs.contains(doc.documentID) else { continue }
            if let user = try await makeFriendUserWithActivity(from: doc, source: .search) {
                users.append(user)
            }
        }
        return users
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

        var users: [FriendUser] = []
        for doc in snapshot.documents {
            guard doc.documentID != currentUID, !excludedUIDs.contains(doc.documentID) else { continue }
            if let user = try await makeFriendUserWithActivity(from: doc, source: .recent) {
                users.append(user)
            }
            if users.count >= limit { break }
        }
        return users
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

    // MARK: - 보낸 친구 요청 취소
    func cancelSentFriendRequest(from fromUID: String, to toUID: String) async throws {
        guard !fromUID.isEmpty, !toUID.isEmpty, fromUID != toUID else { return }

        try await db.collection("friendRequests")
            .document("\(fromUID)_\(toUID)")
            .updateData(["status": FriendRequestStatus.rejected.rawValue])
    }

    // MARK: - 친구 요청 수락
    func acceptFriendRequest(_ request: FriendRequest, currentUserNickname: String) async throws {
        _ = currentUserNickname
        _ = try await functions
            .httpsCallable("acceptFriendRequest")
            .call(["requestID": request.id])
    }

    // MARK: - 친구 요청 거절
    func rejectFriendRequest(_ requestID: String) async throws {
        try await db.collection("friendRequests")
            .document(requestID)
            .updateData(["status": FriendRequestStatus.rejected.rawValue])
    }

    // MARK: - 공유 플레이리스트 저장
    func saveSharedPlaylist(_ summary: SharedPlaylistSummary) async throws {
        guard !summary.id.isEmpty, !summary.ownerUID.isEmpty else { return }

        var data: [String: Any] = [
            "ownerUID": summary.ownerUID,
            "ownerNickname": summary.ownerNickname,
            "title": summary.title,
            "subtitle": summary.subtitle,
            "trackCount": summary.trackCount,
            "updatedAt": FieldValue.serverTimestamp(),
            "tracks": summary.tracks.map(sharedTrackData(from:))
        ]

        // 대표 커버는 플레이리스트 자체의 값만 사용한다. 값이 사라진 경우에도
        // 과거 문서의 첫 수록곡 커버가 남지 않도록 기존 필드를 제거한다.
        if let artworkURL = summary.effectiveArtworkURL {
            data["artworkURL"] = artworkURL
        } else {
            data["artworkURL"] = FieldValue.delete()
        }
        if let artworkData = summary.artworkData, !artworkData.isEmpty {
            data["artworkData"] = artworkData
        } else {
            data["artworkData"] = FieldValue.delete()
        }
        if let sourcePlaylistID = summary.sourcePlaylistID, !sourcePlaylistID.isEmpty {
            data["sourcePlaylistID"] = sourcePlaylistID
        }
        if let sourcePlaylistURL = summary.sourcePlaylistURL, !sourcePlaylistURL.isEmpty {
            data["sourcePlaylistURL"] = sourcePlaylistURL
        }

        try await db.collection("sharedPlaylists")
            .document(summary.id)
            .setData(data, merge: true)
    }

    // MARK: - 친구 공유 플레이리스트 조회
    func fetchFriendSharedPlaylists(currentUID: String, limit: Int = 12) async throws -> [SharedPlaylistSummary] {
        let friends = try await fetchFriends(uid: currentUID)
        guard !friends.isEmpty else { return [] }

        let friendIDs = friends.prefix(8).map(\.id)
        var summaries: [SharedPlaylistSummary] = []

        // 한 번에 너무 많은 Firestore 요청을 보내지 않되, 친구별 조회를 순차
        // 실행하지 않아 첫 화면 대기 시간을 줄인다.
        for batchStartIndex in stride(from: 0, to: friendIDs.count, by: 4) {
            let batch = friendIDs[batchStartIndex..<min(batchStartIndex + 4, friendIDs.count)]
            let batchSummaries = try await withThrowingTaskGroup(of: [SharedPlaylistSummary].self) { group in
                for friendID in batch {
                    group.addTask { @MainActor [db] in
                        let snapshot = try await db.collection("sharedPlaylists")
                            .whereField("ownerUID", isEqualTo: friendID)
                            .limit(to: 10)
                            .getDocuments()

                        return snapshot.documents
                            .compactMap(self.makeSharedPlaylistSummary(from:))
                            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
                            .prefix(3)
                            .map { $0 }
                    }
                }

                var results: [SharedPlaylistSummary] = []
                for try await playlists in group {
                    results.append(contentsOf: playlists)
                }
                return results
            }
            summaries.append(contentsOf: batchSummaries)
        }

        return Array(
            summaries
                .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
                .prefix(limit)
        )
    }

    // MARK: - 플레이리스트 저장 여부 조회
    func isSavedSharedPlaylist(uid: String, playlistID: String) async throws -> Bool {
        guard !uid.isEmpty, !playlistID.isEmpty else { return false }
        let doc = try await db.collection("users")
            .document(uid)
            .collection("savedSharedPlaylists")
            .document(playlistID)
            .getDocument()
        // 과거 버전은 Firestore 문서만 만들고 Apple Music에는 저장하지 않았으므로,
        // 실제 보관함 생성 식별자가 있는 경우만 저장 완료로 간주한다.
        return !(doc.data()?["appleMusicLibraryPlaylistID"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    // MARK: - 공유 플레이리스트 저장
    func saveSharedPlaylistToLibrary(
        uid: String,
        summary: SharedPlaylistSummary,
        appleMusicLibraryPlaylistID: String? = nil
    ) async throws {
        guard !uid.isEmpty else { return }

        var data: [String: Any] = [
            "ownerUID": summary.ownerUID,
            "ownerNickname": summary.ownerNickname,
            "title": summary.title,
            "subtitle": summary.subtitle,
            "trackCount": summary.trackCount,
            "savedAt": FieldValue.serverTimestamp(),
            "tracks": summary.tracks.map(sharedTrackData(from:))
        ]

        if let artworkURL = summary.artworkURL, !artworkURL.isEmpty {
            data["artworkURL"] = artworkURL
        }
        if let artworkData = summary.artworkData, !artworkData.isEmpty {
            data["artworkData"] = artworkData
        }
        if let sourcePlaylistID = summary.sourcePlaylistID, !sourcePlaylistID.isEmpty {
            data["sourcePlaylistID"] = sourcePlaylistID
        }
        if let sourcePlaylistURL = summary.sourcePlaylistURL, !sourcePlaylistURL.isEmpty {
            data["sourcePlaylistURL"] = sourcePlaylistURL
        }
        if let appleMusicLibraryPlaylistID,
           !appleMusicLibraryPlaylistID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["appleMusicLibraryPlaylistID"] = appleMusicLibraryPlaylistID
        }

        try await db.collection("users")
            .document(uid)
            .collection("savedSharedPlaylists")
            .document(summary.id)
            .setData(data, merge: true)
    }

    private func fetchFriendUser(uid: String, source: FriendRecommendationSource) async throws -> FriendUser {
        let doc = try await db.collection("users").document(uid).getDocument()
        return try await makeFriendUserWithActivity(from: doc, source: source) ?? FriendUser(
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

    private func makeFriendUserWithActivity(from doc: DocumentSnapshot, source: FriendRecommendationSource) async throws -> FriendUser? {
        guard let baseUser = makeFriendUser(from: doc, source: source) else { return nil }
        if baseUser.statusText != "최근 활동 없음" {
            return baseUser
        }

        let lastRunDate = try? await fetchLastRunDate(uid: doc.documentID)
        return FriendUser(
            id: baseUser.id,
            nickname: baseUser.nickname,
            profileImageBase64: baseUser.profileImageBase64,
            statusText: FriendActivityText.runningStatus(lastRunDate: lastRunDate),
            source: source
        )
    }

    private func makeSharedPlaylistSummary(from doc: DocumentSnapshot) -> SharedPlaylistSummary? {
        guard let data = doc.data(),
              let ownerUID = data["ownerUID"] as? String,
              let ownerNickname = data["ownerNickname"] as? String,
              let title = data["title"] as? String
        else { return nil }

        let tracks = (data["tracks"] as? [[String: Any]] ?? []).compactMap(makeSharedTrack(from:))

        return SharedPlaylistSummary(
            id: doc.documentID,
            ownerUID: ownerUID,
            ownerNickname: ownerNickname,
            title: title,
            subtitle: data["subtitle"] as? String ?? "",
            artworkURL: data["artworkURL"] as? String,
            artworkData: data["artworkData"] as? String,
            sourcePlaylistID: data["sourcePlaylistID"] as? String,
            sourcePlaylistURL: data["sourcePlaylistURL"] as? String,
            trackCount: (data["trackCount"] as? NSNumber)?.intValue ?? tracks.count,
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
            tracks: tracks
        )
    }

    private func makeSharedTrack(from data: [String: Any]) -> SharedPlaylistTrack? {
        guard let title = data["title"] as? String,
              let artistName = data["artistName"] as? String
        else { return nil }

        return SharedPlaylistTrack(
            id: data["id"] as? String ?? UUID().uuidString,
            title: title,
            artistName: artistName,
            albumTitle: data["albumTitle"] as? String ?? "",
            songStoreID: data["songStoreID"] as? String,
            artworkURL: data["artworkURL"] as? String,
            durationText: data["durationText"] as? String ?? ""
        )
    }

    private func sharedTrackData(from track: SharedPlaylistTrack) -> [String: Any] {
        var data: [String: Any] = [
            "id": track.id,
            "title": track.title,
            "artistName": track.artistName,
            "albumTitle": track.albumTitle,
            "durationText": track.durationText
        ]

        if let songStoreID = track.songStoreID, !songStoreID.isEmpty {
            data["songStoreID"] = songStoreID
        }
        if let artworkURL = track.artworkURL, !artworkURL.isEmpty {
            data["artworkURL"] = artworkURL
        }

        return data
    }
}
