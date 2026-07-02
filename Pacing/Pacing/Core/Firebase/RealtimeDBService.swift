import Foundation
import FirebaseDatabase
import CoreLocation

struct ActiveRunner: Identifiable {
    let id: String
    let nickname: String
    let coordinate: CLLocationCoordinate2D
    let songTitle: String
    let artist: String
    let profileImageBase64: String?
    let updatedAt: TimeInterval
}

final class RealtimeDBService {
    static let shared = RealtimeDBService()
    private let db = Database.database(url: "https://pacing-a8639-default-rtdb.firebaseio.com").reference()
    private var broadcastTimer: Timer?
    private var observeHandle: DatabaseHandle?

    private init() {}

    // MARK: - 브로드캐스트 시작
    func startBroadcast(
        uid: String,
        nickname: String,
        locationProvider: @escaping () -> CLLocationCoordinate2D?,
        songProvider: @escaping () -> (title: String, artist: String),
        profileImageProvider: @escaping () -> String?
    ) {
        guard !uid.isEmpty else { return }
        stopBroadcast(uid: uid)
        db.child("activeRunners").child(uid).onDisconnectRemoveValue()

        broadcastTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            let coord = locationProvider()
            let song = songProvider()
            let profileImageBase64 = profileImageProvider()
            self?.upload(uid: uid, nickname: nickname, coord: coord, song: song, profileImageBase64: profileImageBase64)
        }
        broadcastTimer?.fire()
    }

    func refreshBroadcast(
        uid: String,
        nickname: String,
        coord: CLLocationCoordinate2D?,
        song: (title: String, artist: String),
        profileImageBase64: String? = nil
    ) {
        upload(uid: uid, nickname: nickname, coord: coord, song: song, profileImageBase64: profileImageBase64)
    }

    private func upload(
        uid: String,
        nickname: String,
        coord: CLLocationCoordinate2D?,
        song: (title: String, artist: String),
        profileImageBase64: String?
    ) {
        guard !uid.isEmpty else { return }
        var data: [String: Any] = [
            "nickname": nickname,
            "currentSongTitle": song.title,
            "currentArtist": song.artist,
            "updatedAt": ServerValue.timestamp()
        ]
        if let profileImageBase64, !profileImageBase64.isEmpty {
            data["profileImageBase64"] = profileImageBase64
        }
        if let coord = coord {
            data["latitude"] = coord.latitude
            data["longitude"] = coord.longitude
        }
        db.child("activeRunners").child(uid).updateChildValues(data)
    }

    // MARK: - 브로드캐스트 중지
    func stopBroadcast(uid: String) {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        guard !uid.isEmpty else { return }
        db.child("activeRunners").child(uid).removeValue()
    }

    // MARK: - 주변 러너 구독
    func observeActiveRunners(onChange: @escaping ([ActiveRunner]) -> Void) {
        observeHandle = db.child("activeRunners").observe(.value) { snapshot in
            var runners: [ActiveRunner] = []
            for child in snapshot.children {
                guard
                    let snap = child as? DataSnapshot,
                    let d = snap.value as? [String: Any]
                else { continue }

                let lat = d["latitude"] as? Double ?? 0
                let lng = d["longitude"] as? Double ?? 0

                let runner = ActiveRunner(
                    id: snap.key,
                    nickname: d["nickname"] as? String ?? "러너",
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    songTitle: d["currentSongTitle"] as? String ?? "",
                    artist: d["currentArtist"] as? String ?? "",
                    profileImageBase64: d["profileImageBase64"] as? String,
                    updatedAt: d["updatedAt"] as? TimeInterval ?? 0
                )
                runners.append(runner)
            }
            onChange(runners)
        }
    }

    // MARK: - 구독 해제
    func stopObserving() {
        if let handle = observeHandle {
            db.child("activeRunners").removeObserver(withHandle: handle)
            observeHandle = nil
        }
    }

    // MARK: - 같이 듣기 세션 생성 (호스트)
    @discardableResult
    func createListenSession(
        hostUID: String, hostNickname: String,
        guestUID: String, guestNickname: String,
        songStoreID: String, songTitle: String, artistName: String,
        artworkURL: String = "",
        artworkData: String = "",
        position: Double
    ) -> String {
        guard !hostUID.isEmpty, !guestUID.isEmpty else { return "" }
        let sessionRef = db.child("listenSessions").childByAutoId()
        let sessionID = sessionRef.key ?? UUID().uuidString
        let data: [String: Any] = [
            "hostUID": hostUID,
            "hostNickname": hostNickname,
            "guestUID": guestUID,
            "guestNickname": guestNickname,
            "songStoreID": songStoreID,
            "songTitle": songTitle,
            "artistName": artistName,
            "artworkURL": artworkURL,
            "artworkData": artworkData,
            "playbackPosition": position,
            "serverTimestamp": ServerValue.timestamp(),
            "status": "pending",
            "isPlaying": true
        ]
        sessionRef.setValue(data)
        // 게스트에게 수신 알림 경로에도 기록
        db.child("incomingRequests").child(guestUID).child(sessionID).setValue(data)
        return sessionID
    }

    // MARK: - 세션 수락 (게스트)
    func acceptSession(sessionID: String, guestUID: String) {
        guard !sessionID.isEmpty, !guestUID.isEmpty else { return }
        db.child("listenSessions").child(sessionID).updateChildValues(["status": "active"])
        db.child("incomingRequests").child(guestUID).child(sessionID).removeValue()
    }

    // MARK: - 세션 거절 (게스트)
    func rejectSession(sessionID: String, guestUID: String) {
        guard !sessionID.isEmpty, !guestUID.isEmpty else { return }
        db.child("listenSessions").child(sessionID).updateChildValues(["status": "rejected"])
        db.child("incomingRequests").child(guestUID).child(sessionID).removeValue()
    }

    // MARK: - 재생 상태 브로드캐스트 (호스트)
    func updateSessionPlayback(
        sessionID: String,
        songStoreID: String, songTitle: String, artistName: String,
        artworkURL: String = "",
        artworkData: String = "",
        position: Double, isPlaying: Bool
    ) {
        guard !sessionID.isEmpty else { return }
        db.child("listenSessions").child(sessionID).updateChildValues([
            "songStoreID": songStoreID,
            "songTitle": songTitle,
            "artistName": artistName,
            "artworkURL": artworkURL,
            "artworkData": artworkData,
            "playbackPosition": position,
            "serverTimestamp": ServerValue.timestamp(),
            "isPlaying": isPlaying
        ])
    }

    // MARK: - 세션 구독
    private var sessionHandle: DatabaseHandle?

    func observeSession(sessionID: String, onChange: @escaping (ListenSession) -> Void) {
        guard !sessionID.isEmpty else { return }
        sessionHandle = db.child("listenSessions").child(sessionID).observe(.value) { snapshot in
            guard let d = snapshot.value as? [String: Any] else { return }
            let session = ListenSession(
                id: sessionID,
                hostUID: d["hostUID"] as? String ?? "",
                hostNickname: d["hostNickname"] as? String ?? "",
                guestUID: d["guestUID"] as? String ?? "",
                guestNickname: d["guestNickname"] as? String ?? "",
                songStoreID: d["songStoreID"] as? String ?? "",
                songTitle: d["songTitle"] as? String ?? "",
                artistName: d["artistName"] as? String ?? "",
                artworkURL: d["artworkURL"] as? String ?? "",
                artworkData: d["artworkData"] as? String ?? "",
                playbackPosition: (d["playbackPosition"] as? NSNumber)?.doubleValue ?? 0,
                serverTimestamp: (d["serverTimestamp"] as? NSNumber)?.doubleValue ?? 0,
                status: d["status"] as? String ?? "ended",
                isPlaying: d["isPlaying"] as? Bool ?? false
            )
            onChange(session)
        }
    }

    func stopObservingSession() {
        if let handle = sessionHandle {
            db.child("listenSessions").removeObserver(withHandle: handle)
            sessionHandle = nil
        }
    }

    // MARK: - 수신 요청 구독 (게스트)
    private var incomingHandle: DatabaseHandle?

    func observeIncomingRequests(uid: String, onChange: @escaping (ListenSession?) -> Void) {
        guard !uid.isEmpty else { return }
        incomingHandle = db.child("incomingRequests").child(uid).observe(.value) { snapshot in
            guard snapshot.childrenCount > 0 else { onChange(nil); return }
            // 가장 최신 요청 하나만 처리
            if let child = snapshot.children.allObjects.last as? DataSnapshot,
               let d = child.value as? [String: Any] {
                let session = ListenSession(
                    id: child.key,
                    hostUID: d["hostUID"] as? String ?? "",
                    hostNickname: d["hostNickname"] as? String ?? "",
                    guestUID: d["guestUID"] as? String ?? "",
                    guestNickname: d["guestNickname"] as? String ?? "",
                    songStoreID: d["songStoreID"] as? String ?? "",
                    songTitle: d["songTitle"] as? String ?? "",
                    artistName: d["artistName"] as? String ?? "",
                    artworkURL: d["artworkURL"] as? String ?? "",
                    artworkData: d["artworkData"] as? String ?? "",
                    playbackPosition: (d["playbackPosition"] as? NSNumber)?.doubleValue ?? 0,
                    serverTimestamp: (d["serverTimestamp"] as? NSNumber)?.doubleValue ?? 0,
                    status: d["status"] as? String ?? "pending",
                    isPlaying: d["isPlaying"] as? Bool ?? true
                )
                onChange(session)
            } else {
                onChange(nil)
            }
        }
    }

    func stopObservingIncomingRequests(uid: String) {
        if let handle = incomingHandle, !uid.isEmpty {
            db.child("incomingRequests").child(uid).removeObserver(withHandle: handle)
            incomingHandle = nil
        }
    }

    // MARK: - 세션 종료
    func endSession(sessionID: String) {
        guard !sessionID.isEmpty else { return }
        db.child("listenSessions").child(sessionID).updateChildValues(["status": "ended"])
    }

    // MARK: - 최근 같이 듣기 세션 조회

    func fetchRecentListenSessions(uid: String, limit: Int = 10) async throws -> [ListenSession] {
        guard !uid.isEmpty else { return [] }

        async let hostSessions = fetchListenSessions(where: "hostUID", equals: uid, limit: limit)
        async let guestSessions = fetchListenSessions(where: "guestUID", equals: uid, limit: limit)

        let merged = try await hostSessions + guestSessions
        let unique = Dictionary(grouping: merged, by: \.id).compactMap { $0.value.first }

        return unique
            .filter { $0.status == "active" || $0.status == "ended" }
            .sorted { $0.serverTimestamp > $1.serverTimestamp }
            .prefix(limit)
            .map { $0 }
    }

    private func fetchListenSessions(where child: String, equals uid: String, limit: Int) async throws -> [ListenSession] {
        try await withCheckedThrowingContinuation { continuation in
            db.child("listenSessions")
                .queryOrdered(byChild: child)
                .queryEqual(toValue: uid)
                .queryLimited(toLast: UInt(limit))
                .observeSingleEvent(of: .value) { snapshot in
                    var sessions: [ListenSession] = []

                    for childSnapshot in snapshot.children {
                        guard
                            let snap = childSnapshot as? DataSnapshot,
                            let d = snap.value as? [String: Any]
                        else { continue }

                        sessions.append(
                            ListenSession(
                                id: snap.key,
                                hostUID: d["hostUID"] as? String ?? "",
                                hostNickname: d["hostNickname"] as? String ?? "",
                                guestUID: d["guestUID"] as? String ?? "",
                                guestNickname: d["guestNickname"] as? String ?? "",
                                songStoreID: d["songStoreID"] as? String ?? "",
                                songTitle: d["songTitle"] as? String ?? "",
                                artistName: d["artistName"] as? String ?? "",
                                artworkURL: d["artworkURL"] as? String ?? "",
                                artworkData: d["artworkData"] as? String ?? "",
                                playbackPosition: (d["playbackPosition"] as? NSNumber)?.doubleValue ?? 0,
                                serverTimestamp: (d["serverTimestamp"] as? NSNumber)?.doubleValue ?? 0,
                                status: d["status"] as? String ?? "ended",
                                isPlaying: d["isPlaying"] as? Bool ?? false
                            )
                        )
                    }

                    continuation.resume(returning: sessions)
                }
        }
    }
}
