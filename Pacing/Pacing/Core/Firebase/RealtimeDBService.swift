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
            "isPlaying": isPlaying
        ]
        sessionRef.setValue(data)
        // 요청을 받은 호스트에게 수신 알림 경로에도 기록합니다.
        // 세션의 guestUID는 요청자이므로 알림 수신자와 분리해야 합니다.
        db.child("incomingRequests").child(hostUID).child(sessionID).setValue(data)
        return sessionID
    }

    // MARK: - 세션 수락 (게스트)
    func acceptSession(sessionID: String, hostUID: String) {
        guard !sessionID.isEmpty, !hostUID.isEmpty else { return }
        db.child("listenSessions").child(sessionID).updateChildValues(["status": "active"])
        db.child("incomingRequests").child(hostUID).child(sessionID).removeValue()
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
