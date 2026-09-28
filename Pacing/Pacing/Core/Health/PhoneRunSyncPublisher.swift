import CoreLocation
import FirebaseAuth
import Foundation
import WatchConnectivity

final class PhoneRunSyncPublisher: NSObject {
    static let shared = PhoneRunSyncPublisher()
    private let session = WCSession.default
    private let maximumMusicContextSize = 58_000

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func publish(_ snapshot: PhoneRunSnapshot, persist: Bool) {
        guard let data = try? JSONEncoder().encode(snapshot),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        if persist { try? session.updateApplicationContext(["phoneRun": payload]) }
        if session.isReachable { session.sendMessage(["phoneRun": payload], replyHandler: nil) }
    }

    func send(_ command: PhoneRunCommand) {
        guard let data = try? JSONEncoder().encode(command),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if session.isReachable {
            session.sendMessage(["phoneRunCommand": payload], replyHandler: nil)
        } else {
            session.transferUserInfo(["phoneRunCommand": payload])
        }
    }

    func publishMusic(_ snapshot: PhoneMusicPlaybackSnapshot) {
        guard let payload = musicPayload(for: snapshot) else { return }

        // 음악은 Watch가 늦게 연결돼도 최근 상태를 복구해야 하므로 application context에 보관합니다.
        var context = session.applicationContext
        context["phoneMusic"] = payload
        if let contextData = try? JSONSerialization.data(withJSONObject: context),
           contextData.count <= maximumMusicContextSize {
            try? session.updateApplicationContext(context)
        }
        if session.isReachable { session.sendMessage(["phoneMusic": payload], replyHandler: nil) }
    }

    func publishRunHistory(records: [RunRecord], calendar: Calendar = .current) {
        let snapshot = makeRunHistorySnapshot(records: records, calendar: calendar)
        guard let data = try? JSONEncoder().encode(snapshot),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        var context = session.applicationContext
        context["phoneRunHistory"] = payload
        if let contextData = try? JSONSerialization.data(withJSONObject: context),
           contextData.count <= maximumMusicContextSize {
            try? session.updateApplicationContext(context)
        }
        if session.isReachable { session.sendMessage(["phoneRunHistory": payload], replyHandler: nil) }
    }

    private func musicPayload(for snapshot: PhoneMusicPlaybackSnapshot) -> [String: Any]? {
        for candidate in [snapshot, snapshot.removingRecentArtworkData(), snapshot.removingAllArtworkData()] {
            guard let data = try? JSONEncoder().encode(candidate),
                  data.count <= maximumMusicContextSize,
                  let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            return payload
        }
        return nil
    }

    private func makeRunHistorySnapshot(
        records: [RunRecord],
        calendar: Calendar
    ) -> PhoneRunHistorySnapshot {
        let now = Date()
        let validRecords = records
            .filter(\.isPaceValid)
            .filter { $0.startedAt <= now }
            .sorted { $0.startedAt > $1.startedAt }

        let currentMonthRecords = validRecords.filter {
            calendar.isDate($0.startedAt, equalTo: now, toGranularity: .month)
        }

        return PhoneRunHistorySnapshot(
            monthDistanceKilometers: currentMonthRecords.reduce(0) { $0 + $1.distance },
            monthRunCount: currentMonthRecords.count,
            recentRuns: validRecords.prefix(10).map { record in
                PhoneRunHistoryItem(
                    id: record.id,
                    startedAt: record.startedAt,
                    durationSeconds: record.duration,
                    distanceKilometers: record.distance,
                    averagePaceMinutesPerKilometer: record.displayPace,
                    elevationGainMeters: record.elevationGainMeters,
                    averageHeartRate: record.averageHeartRate,
                    averageCadence: record.averageCadence,
                    routePoints: compactRoutePoints(from: record.routeCoordinates)
                )
            },
            updatedAt: now
        )
    }

    private func compactRoutePoints(
        from coordinates: [CLLocationCoordinate2D],
        maximumPointCount: Int = 40
    ) -> [PhoneRunHistoryRoutePoint] {
        guard coordinates.count > maximumPointCount else {
            return coordinates.map {
                PhoneRunHistoryRoutePoint(latitude: $0.latitude, longitude: $0.longitude)
            }
        }

        let lastIndex = coordinates.count - 1
        return (0..<maximumPointCount).map { index in
            let coordinateIndex = Int(
                (Double(index) * Double(lastIndex) / Double(maximumPointCount - 1)).rounded()
            )
            let coordinate = coordinates[coordinateIndex]
            return PhoneRunHistoryRoutePoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }
}

extension PhoneRunSyncPublisher: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        PhoneRunCommandReceiver.shared.consume(message)
        PhoneMusicCommandReceiver.shared.consume(message)
        refreshRunHistoryIfRequested(by: message)
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        PhoneRunCommandReceiver.shared.consume(applicationContext)
        PhoneMusicCommandReceiver.shared.consume(applicationContext)
        refreshRunHistoryIfRequested(by: applicationContext)
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        PhoneRunCommandReceiver.shared.consume(userInfo)
        PhoneMusicCommandReceiver.shared.consume(userInfo)
        refreshRunHistoryIfRequested(by: userInfo)
    }

    private func refreshRunHistoryIfRequested(by container: [String: Any]) {
        guard container["watchRunHistoryRefresh"] as? Bool == true,
              let uid = Auth.auth().currentUser?.uid
        else { return }

        Task { [weak self] in
            guard let self,
                  let records = try? await FirestoreService.shared.fetchRunHistory(uid: uid, limit: 100)
            else { return }
            self.publishRunHistory(records: records)
        }
    }
}
