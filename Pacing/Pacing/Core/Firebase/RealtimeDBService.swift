import Foundation
import FirebaseDatabase
import CoreLocation
import UIKit

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

enum ActiveRunnerBroadcastMode {
    case foreground
    case background
    case running

    var minimumInterval: TimeInterval {
        switch self {
        case .foreground: return 15
        case .background: return 60
        case .running: return 5
        }
    }

    var minimumDistance: CLLocationDistance {
        switch self {
        case .foreground: return 30
        case .background: return 50
        case .running: return 10
        }
    }
}

final class RealtimeDBService {
    static let shared = RealtimeDBService()
    private let db = Database.database(url: "https://pacing-a8639-default-rtdb.firebaseio.com").reference()
    private var broadcastTimer: Timer?
    private var activeRunnerObserverHandles: [DatabaseHandle] = []
    private var activeRunnerCleanupTimer: Timer?
    private var activeRunnerCache: [String: ActiveRunner] = [:]
    private var lastBroadcastCoordinate: CLLocationCoordinate2D?
    private var lastBroadcastDate: Date?
    private var lastBroadcastSong: (title: String, artist: String)?
    private var broadcastErrorHandler: ((Error) -> Void)?

    private init() {}

    // MARK: - 브로드캐스트 시작
    func startBroadcast(
        uid: String,
        nickname: String,
        locationProvider: @escaping () -> CLLocationCoordinate2D?,
        songProvider: @escaping () -> (title: String, artist: String),
        isRunningProvider: @escaping () -> Bool = { false },
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
            let mode = Self.broadcastMode(isRunning: isRunningProvider())
            self?.upload(uid: uid, nickname: nickname, coord: coord, song: song, mode: mode)
        }
        broadcastTimer?.fire()
    }

    func refreshBroadcast(
        uid: String,
        nickname: String,
        coord: CLLocationCoordinate2D?,
        song: (title: String, artist: String),
        isRunning: Bool = false
    ) {
        upload(
            uid: uid,
            nickname: nickname,
            coord: coord,
            song: song,
            mode: Self.broadcastMode(isRunning: isRunning)
        )
    }

    private func upload(
        uid: String,
        nickname: String,
        coord: CLLocationCoordinate2D?,
        song: (title: String, artist: String),
        mode: ActiveRunnerBroadcastMode
    ) {
        guard !uid.isEmpty,
              let coord,
              CLLocationCoordinate2DIsValid(coord)
        else { return }

        let now = Date()
        let distance = lastBroadcastCoordinate.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        } ?? .greatestFiniteMagnitude
        let elapsed = lastBroadcastDate.map { now.timeIntervalSince($0) } ?? .greatestFiniteMagnitude
        let songChanged = lastBroadcastSong?.title != song.title || lastBroadcastSong?.artist != song.artist

        guard lastBroadcastDate == nil || elapsed >= mode.minimumInterval ||
                distance >= mode.minimumDistance || songChanged else { return }

        var data: [String: Any] = [
            "nickname": nickname,
            "currentSongTitle": song.title,
            "currentArtist": song.artist,
            "updatedAt": ServerValue.timestamp()
        ]
        data["latitude"] = coord.latitude
        data["longitude"] = coord.longitude
        db.child("activeRunners").child(uid).updateChildValues(data) { [weak self] error, _ in
            guard let self else { return }
            if let error {
                self.broadcastErrorHandler?(error)
            } else {
                self.lastBroadcastCoordinate = coord
                self.lastBroadcastDate = now
                self.lastBroadcastSong = song
            }
        }
    }

    // MARK: - 브로드캐스트 중지
    func stopBroadcast(uid: String) {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        lastBroadcastCoordinate = nil
        lastBroadcastDate = nil
        lastBroadcastSong = nil
        guard !uid.isEmpty else { return }
        db.child("activeRunners").child(uid).removeValue()
    }

    // MARK: - 주변 러너 구독
    func observeActiveRunners(
        onChange: @escaping ([ActiveRunner]) -> Void,
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        stopObserving()
        activeRunnerCache.removeAll(keepingCapacity: true)

        let reference = db.child("activeRunners")
        let addedHandle = reference.observe(.childAdded, with: { [weak self] snapshot in
            self?.updateActiveRunner(snapshot, onChange: onChange)
        }, withCancel: onError)
        let changedHandle = reference.observe(.childChanged, with: { [weak self] snapshot in
            self?.updateActiveRunner(snapshot, onChange: onChange)
        }, withCancel: onError)
        let removedHandle = reference.observe(.childRemoved, with: { [weak self] snapshot in
            self?.activeRunnerCache.removeValue(forKey: snapshot.key)
            self?.publishActiveRunners(onChange)
        }, withCancel: onError)
        activeRunnerObserverHandles = [addedHandle, changedHandle, removedHandle]

        activeRunnerCleanupTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.removeStaleActiveRunners(onChange: onChange)
        }
    }

    private func updateActiveRunner(_ snapshot: DataSnapshot, onChange: @escaping ([ActiveRunner]) -> Void) {
        guard let runner = Self.activeRunner(from: snapshot) else {
            activeRunnerCache.removeValue(forKey: snapshot.key)
            publishActiveRunners(onChange)
            return
        }
        activeRunnerCache[runner.id] = runner
        publishActiveRunners(onChange)
    }

    private static func activeRunner(from snapshot: DataSnapshot) -> ActiveRunner? {
        guard let d = snapshot.value as? [String: Any],
              let lat = Self.doubleValue(d["latitude"]),
              let lng = Self.doubleValue(d["longitude"]),
              let updatedAt = Self.doubleValue(d["updatedAt"]),
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        else { return nil }

        return ActiveRunner(
            id: snapshot.key,
            nickname: d["nickname"] as? String ?? "러너",
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            songTitle: d["currentSongTitle"] as? String ?? "",
            artist: d["currentArtist"] as? String ?? "",
            profileImageBase64: d["profileImageBase64"] as? String,
            updatedAt: updatedAt
        )
    }

    private func publishActiveRunners(_ onChange: @escaping ([ActiveRunner]) -> Void) {
        onChange(activeRunnerCache.values.filter { $0.isFresh() }.sorted { $0.id < $1.id })
    }

    private func removeStaleActiveRunners(onChange: @escaping ([ActiveRunner]) -> Void) {
        let staleIDs = activeRunnerCache.values.filter { !$0.isFresh() }.map(\.id)
        guard !staleIDs.isEmpty else { return }
        staleIDs.forEach { activeRunnerCache.removeValue(forKey: $0) }
        publishActiveRunners(onChange)
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        return value as? Double
    }

    // MARK: - 구독 해제
    func stopObserving() {
        let reference = db.child("activeRunners")
        activeRunnerObserverHandles.forEach { reference.removeObserver(withHandle: $0) }
        activeRunnerObserverHandles.removeAll()
        activeRunnerCleanupTimer?.invalidate()
        activeRunnerCleanupTimer = nil
        activeRunnerCache.removeAll()
    }

    private static func broadcastMode(isRunning: Bool) -> ActiveRunnerBroadcastMode {
        if isRunning { return .running }
        return UIApplication.shared.applicationState == .active ? .foreground : .background
    }

    /// 요청 버튼을 누른 순간의 상대방 재생 곡을 한 번 읽습니다.
    /// 화면에 캐시된 NearbyRunner 값은 실시간 갱신 사이에 이전 곡일 수 있으므로
    /// 요청 생성 시에는 activeRunners의 최신 값을 기준으로 사용합니다.
    func fetchActiveRunner(uid: String) async throws -> ActiveRunner? {
        guard !uid.isEmpty else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            db.child("activeRunners").child(uid).observeSingleEvent(of: .value) { snapshot in
                let runner = Self.activeRunner(from: snapshot)
                continuation.resume(returning: runner?.isFresh() == true ? runner : nil)
            } withCancel: { error in
                continuation.resume(throwing: error)
            }
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
        position: Double,
        isPlaying: Bool
    ) -> String {
        guard !hostUID.isEmpty, !guestUID.isEmpty else { return "" }
        let sessionRef = db.child("listenSessions").childByAutoId()
        let sessionID = sessionRef.key ?? UUID().uuidString
        let metadata: [String: Any] = [
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
            "artworkData": artworkData
        ]
        let playback: [String: Any] = [
            "songStoreID": songStoreID,
            "songTitle": songTitle,
            "artistName": artistName,
            "playbackEventID": playbackEventID,
            "playbackPosition": position,
            "serverTimestamp": ServerValue.timestamp(),
            "status": "pending",
            "isPlaying": isPlaying
        ]
        // 루트에는 기존 보안 규칙·구버전 클라이언트 호환에 필요한 작은 메타데이터만
        // 유지한다. 프로필·앨범 Base64는 metadata 하위 경로에만 저장한다.
        sessionRef.setValue([
            "metadata": metadata,
            "playback": playback,
            "hostUID": hostUID,
            "hostNickname": hostNickname,
            "guestUID": guestUID,
            "guestNickname": guestNickname,
            "songStoreID": songStoreID,
            "songTitle": songTitle,
            "artistName": artistName,
            "artworkURL": artworkURL,
            "status": "pending"
        ])
        // 요청을 받은 호스트에게 수신 알림 경로에도 기록합니다.
        // 세션의 guestUID는 요청자이므로 알림 수신자와 분리해야 합니다.
        db.child("incomingRequests").child(hostUID).child(sessionID).setValue(metadata.merging(playback) { _, new in new })
        return sessionID
    }

    // MARK: - 세션 수락 (게스트)
    func acceptSession(sessionID: String, hostUID: String) {
        guard !sessionID.isEmpty, !hostUID.isEmpty else { return }
        db.child("listenSessions").child(sessionID).updateChildValues(["status": "active"])
        db.child("listenSessions").child(sessionID).child("playback").updateChildValues(["status": "active"])
        db.child("incomingRequests").child(hostUID).child(sessionID).removeValue()
    }

    // MARK: - 세션 거절 (게스트)
    func rejectSession(sessionID: String, guestUID: String) {
        guard !sessionID.isEmpty, !guestUID.isEmpty else { return }
        db.child("listenSessions").child(sessionID).updateChildValues(["status": "rejected"])
        db.child("listenSessions").child(sessionID).child("playback").updateChildValues(["status": "rejected"])
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
        let playbackUpdate: [String: Any] = [
            "songStoreID": songStoreID,
            "songTitle": songTitle,
            "artistName": artistName,
            "playbackEventID": playbackEventID,
            "playbackPosition": position,
            "serverTimestamp": ServerValue.timestamp(),
            "isPlaying": isPlaying
        ]
        // 재생 위치 경로에는 이미지·프로필 Base64를 포함하지 않는다.
        db.child("listenSessions").child(sessionID).child("playback").updateChildValues(playbackUpdate)

        // 앨범 메타데이터는 곡 전환 시에만 별도 경로로 갱신한다.
        var metadataUpdate: [String: Any] = [:]
        if let artworkURL { metadataUpdate["artworkURL"] = artworkURL }
        if let artworkData { metadataUpdate["artworkData"] = artworkData }
        if !metadataUpdate.isEmpty {
            db.child("listenSessions").child(sessionID).child("metadata").updateChildValues(metadataUpdate)
            // 구버전 클라이언트와 루트 기반 규칙을 위해 작은 문자열 메타데이터만 mirror한다.
            let rootUpdate = metadataUpdate.filter { $0.key == "artworkURL" }
            if !rootUpdate.isEmpty {
                db.child("listenSessions").child(sessionID).updateChildValues(rootUpdate)
            }
        }
    }

    // MARK: - 세션 구독
    private var sessionMetadataHandle: DatabaseHandle?
    private var sessionPlaybackHandle: DatabaseHandle?
    private var legacySessionHandle: DatabaseHandle?

    func observeSession(sessionID: String, onChange: @escaping (ListenSession) -> Void) {
        guard !sessionID.isEmpty else { return }
        let reference = db.child("listenSessions").child(sessionID)
        reference.child("metadata").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let self else { return }
            guard snapshot.exists(), snapshot.childrenCount > 0 else {
                self.legacySessionHandle = reference.observe(.value) { snapshot in
                    guard let d = snapshot.value as? [String: Any],
                          let session = Self.makeListenSession(id: sessionID, data: d)
                    else { return }
                    onChange(session)
                }
                return
            }

            var metadata: [String: Any] = [:]
            var playback: [String: Any] = [:]
            let publish = {
                guard !metadata.isEmpty,
                      let session = Self.makeListenSession(
                        id: sessionID,
                        metadata: metadata,
                        playback: playback
                      ) else { return }
                onChange(session)
            }
            self.sessionMetadataHandle = reference.child("metadata").observe(.value) { snapshot in
                metadata = snapshot.value as? [String: Any] ?? [:]
                publish()
            }
            self.sessionPlaybackHandle = reference.child("playback").observe(.value) { snapshot in
                playback = snapshot.value as? [String: Any] ?? [:]
                publish()
            }
        })
    }

    func stopObservingSession() {
        let reference = db.child("listenSessions")
        if let handle = sessionMetadataHandle { reference.removeObserver(withHandle: handle) }
        if let handle = sessionPlaybackHandle { reference.removeObserver(withHandle: handle) }
        if let handle = legacySessionHandle { reference.removeObserver(withHandle: handle) }
        sessionMetadataHandle = nil
        sessionPlaybackHandle = nil
        legacySessionHandle = nil
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
                onChange(Self.makeListenSession(id: child.key, data: d))
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
        db.child("listenSessions").child(sessionID).child("playback").updateChildValues(["status": "ended"])
    }

    // MARK: - 최근 같이 듣기 세션 조회

    func fetchRecentListenSessions(uid: String, limit: Int = 10) async throws -> [ListenSession] {
        guard !uid.isEmpty else { return [] }

        async let legacyHostSessions = fetchListenSessions(where: "hostUID", equals: uid, limit: limit)
        async let legacyGuestSessions = fetchListenSessions(where: "guestUID", equals: uid, limit: limit)
        async let structuredHostSessions = fetchListenSessions(where: "metadata/hostUID", equals: uid, limit: limit)
        async let structuredGuestSessions = fetchListenSessions(where: "metadata/guestUID", equals: uid, limit: limit)

        let merged = try await legacyHostSessions
            + legacyGuestSessions
            + structuredHostSessions
            + structuredGuestSessions
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

                        if let session = Self.makeListenSession(id: snap.key, data: d) {
                            sessions.append(session)
                        }
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

    private static func makeListenSession(
        id: String,
        metadata: [String: Any],
        playback: [String: Any]
    ) -> ListenSession? {
        var data = metadata
        data.merge(playback) { _, new in new }
        return makeListenSession(id: id, data: data)
    }

    private static func makeListenSession(id: String, data: [String: Any]) -> ListenSession? {
        let metadata = data["metadata"] as? [String: Any]
        let playback = data["playback"] as? [String: Any]
        var merged = data
        if let metadata { merged.merge(metadata) { _, new in new } }
        if let playback { merged.merge(playback) { _, new in new } }

        return ListenSession(
            id: id,
            hostUID: merged["hostUID"] as? String ?? "",
            hostNickname: merged["hostNickname"] as? String ?? "",
            hostProfileImageBase64: merged["hostProfileImageBase64"] as? String ?? "",
            guestUID: merged["guestUID"] as? String ?? "",
            guestNickname: merged["guestNickname"] as? String ?? "",
            guestProfileImageBase64: merged["guestProfileImageBase64"] as? String ?? "",
            songStoreID: merged["songStoreID"] as? String ?? "",
            songTitle: merged["songTitle"] as? String ?? "",
            artistName: merged["artistName"] as? String ?? "",
            artworkURL: merged["artworkURL"] as? String ?? "",
            artworkData: merged["artworkData"] as? String ?? "",
            playbackEventID: merged["playbackEventID"] as? String ?? "",
            playbackPosition: (merged["playbackPosition"] as? NSNumber)?.doubleValue ?? 0,
            serverTimestamp: (merged["serverTimestamp"] as? NSNumber)?.doubleValue ?? 0,
            status: merged["status"] as? String ?? "ended",
            isPlaying: merged["isPlaying"] as? Bool ?? false
        )
    }
}

private enum RealtimeDBRequestError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        "실시간 데이터 요청 시간이 초과되었어요."
    }
}
