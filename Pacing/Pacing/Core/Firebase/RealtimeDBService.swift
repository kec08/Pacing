import Foundation
import FirebaseDatabase
import CoreLocation

struct ActiveRunner: Identifiable {
    static let maximumAge: TimeInterval = 120

    let id: String
    let nickname: String
    let coordinate: CLLocationCoordinate2D
    let songTitle: String
    let artist: String
    let profileImageBase64: String?
    let updatedAt: TimeInterval

    func isFresh(referenceDate: Date = .now) -> Bool {
        updatedAt > 0 && referenceDate.timeIntervalSince1970 * 1_000 - updatedAt <= Self.maximumAge * 1_000
    }
}

final class RealtimeDBService {
    static let shared = RealtimeDBService()
    private let db = Database.database(url: "https://pacing-a8639-default-rtdb.firebaseio.com").reference()
    private var broadcastTimer: Timer?
    private var observeHandle: DatabaseHandle?
    private var broadcastErrorHandler: ((Error) -> Void)?

    private init() {}

    // MARK: - 브로드캐스트 시작
    func startBroadcast(
        uid: String,
        nickname: String,
        locationProvider: @escaping () -> CLLocationCoordinate2D?,
        songProvider: @escaping () -> (title: String, artist: String),
        profileImageProvider: @escaping () -> String?,
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        guard !uid.isEmpty else { return }
        broadcastErrorHandler = onError
        stopBroadcast(uid: uid)
        db.child("activeRunners").child(uid).onDisconnectRemoveValue { [weak self] error, _ in
            if let error { self?.broadcastErrorHandler?(error) }
        }

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
        guard !uid.isEmpty,
              let coord,
              CLLocationCoordinate2DIsValid(coord)
        else { return }
        var data: [String: Any] = [
            "nickname": nickname,
            "currentSongTitle": song.title,
            "currentArtist": song.artist,
            "updatedAt": ServerValue.timestamp()
        ]
        if let profileImageBase64, !profileImageBase64.isEmpty {
            data["profileImageBase64"] = profileImageBase64
        }
        data["latitude"] = coord.latitude
        data["longitude"] = coord.longitude
        db.child("activeRunners").child(uid).updateChildValues(data) { [weak self] error, _ in
            if let error { self?.broadcastErrorHandler?(error) }
        }
    }

    // MARK: - 브로드캐스트 중지
    func stopBroadcast(uid: String) {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        guard !uid.isEmpty else { return }
        db.child("activeRunners").child(uid).removeValue()
    }

    // MARK: - 주변 러너 구독
    func observeActiveRunners(
        onChange: @escaping ([ActiveRunner]) -> Void,
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        observeHandle = db.child("activeRunners").observe(.value, with: { snapshot in
            var runners: [ActiveRunner] = []
            runners.reserveCapacity(Int(snapshot.childrenCount))
            for child in snapshot.children {
                guard
                    let snap = child as? DataSnapshot,
                    let d = snap.value as? [String: Any]
                else { continue }

                guard
                    let lat = Self.doubleValue(d["latitude"]),
                    let lng = Self.doubleValue(d["longitude"]),
                    let updatedAt = Self.doubleValue(d["updatedAt"]),
                    CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                else { continue }

                let runner = ActiveRunner(
                    id: snap.key,
                    nickname: d["nickname"] as? String ?? "러너",
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    songTitle: d["currentSongTitle"] as? String ?? "",
                    artist: d["currentArtist"] as? String ?? "",
                    profileImageBase64: d["profileImageBase64"] as? String,
                    updatedAt: updatedAt
                )
                if runner.isFresh() {
                    runners.append(runner)
                }
            }
            onChange(runners)
        }, withCancel: onError)
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        return value as? Double
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
        hostProfileImageBase64: String,
        guestUID: String, guestNickname: String,
        guestProfileImageBase64: String,
        songStoreID: String, songTitle: String, artistName: String,
        artworkURL: String = "",
        artworkData: String = "",
        playbackEventID: String = UUID().uuidString,
        position: Double
    ) -> String {
        guard !hostUID.isEmpty, !guestUID.isEmpty else { return "" }
        let sessionRef = db.child("listenSessions").childByAutoId()
        let sessionID = sessionRef.key ?? UUID().uuidString
        let data: [String: Any] = [
            "hostUID": hostUID,
            "hostNickname": hostNickname,
            "hostProfileImageBase64": hostProfileImageBase64,
            "guestUID": guestUID,
            "guestNickname": guestNickname,
            "guestProfileImageBase64": guestProfileImageBase64,
            "songStoreID": songStoreID,
            "songTitle": songTitle,
            "artistName": artistName,
            "artworkURL": artworkURL,
            "artworkData": artworkData,
            "playbackEventID": playbackEventID,
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
        artworkURL: String? = nil,
        artworkData: String? = nil,
        playbackEventID: String,
        position: Double, isPlaying: Bool
    ) {
        guard !sessionID.isEmpty else { return }
        var update: [String: Any] = [
            "songStoreID": songStoreID,
            "songTitle": songTitle,
            "artistName": artistName,
            "playbackEventID": playbackEventID,
            "playbackPosition": position,
            "serverTimestamp": ServerValue.timestamp(),
            "isPlaying": isPlaying
        ]
        // 앨범 이미지는 곡 전환에만 변경된다. 위치 보정마다 큰 Base64 문자열을 다시 전송하지 않는다.
        if let artworkURL { update["artworkURL"] = artworkURL }
        if let artworkData { update["artworkData"] = artworkData }
        db.child("listenSessions").child(sessionID).updateChildValues(update)
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
                hostProfileImageBase64: d["hostProfileImageBase64"] as? String ?? "",
                guestUID: d["guestUID"] as? String ?? "",
                guestNickname: d["guestNickname"] as? String ?? "",
                guestProfileImageBase64: d["guestProfileImageBase64"] as? String ?? "",
                songStoreID: d["songStoreID"] as? String ?? "",
                songTitle: d["songTitle"] as? String ?? "",
                artistName: d["artistName"] as? String ?? "",
                artworkURL: d["artworkURL"] as? String ?? "",
                artworkData: d["artworkData"] as? String ?? "",
                playbackEventID: d["playbackEventID"] as? String ?? "",
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
                    hostProfileImageBase64: d["hostProfileImageBase64"] as? String ?? "",
                    guestUID: d["guestUID"] as? String ?? "",
                    guestNickname: d["guestNickname"] as? String ?? "",
                    guestProfileImageBase64: d["guestProfileImageBase64"] as? String ?? "",
                    songStoreID: d["songStoreID"] as? String ?? "",
                    songTitle: d["songTitle"] as? String ?? "",
                    artistName: d["artistName"] as? String ?? "",
                    artworkURL: d["artworkURL"] as? String ?? "",
                    artworkData: d["artworkData"] as? String ?? "",
                    playbackEventID: d["playbackEventID"] as? String ?? "",
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
            let lock = NSLock()
            var didResume = false

            func resumeOnce(with result: Result<[ListenSession], Error>) {
                lock.lock()
                defer { lock.unlock() }

                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let query = db.child("listenSessions")
                .queryOrdered(byChild: child)
                .queryEqual(toValue: uid)
                .queryLimited(toLast: UInt(limit))
            query.observeSingleEvent(of: .value) { snapshot in
                    var sessions: [ListenSession] = []
                    sessions.reserveCapacity(Int(snapshot.childrenCount))

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
                                hostProfileImageBase64: d["hostProfileImageBase64"] as? String ?? "",
                                guestUID: d["guestUID"] as? String ?? "",
                                guestNickname: d["guestNickname"] as? String ?? "",
                                guestProfileImageBase64: d["guestProfileImageBase64"] as? String ?? "",
                                songStoreID: d["songStoreID"] as? String ?? "",
                                songTitle: d["songTitle"] as? String ?? "",
                                artistName: d["artistName"] as? String ?? "",
                                artworkURL: d["artworkURL"] as? String ?? "",
                                artworkData: d["artworkData"] as? String ?? "",
                                playbackEventID: d["playbackEventID"] as? String ?? "",
                                playbackPosition: (d["playbackPosition"] as? NSNumber)?.doubleValue ?? 0,
                                serverTimestamp: (d["serverTimestamp"] as? NSNumber)?.doubleValue ?? 0,
                                status: d["status"] as? String ?? "ended",
                                isPlaying: d["isPlaying"] as? Bool ?? false
                            )
                        )
                    }

                    resumeOnce(with: .success(sessions))
                } withCancel: { error in
                    resumeOnce(with: .failure(error))
                }

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                resumeOnce(with: .failure(RealtimeDBRequestError.timedOut))
            }
        }
    }
}

private enum RealtimeDBRequestError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        "실시간 데이터 요청 시간이 초과되었어요."
    }
}
