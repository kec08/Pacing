import Foundation
import FirebaseFirestore
import CoreLocation

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - 프로필 저장
    func saveUserProfile(uid: String, nickname: String, height: Int, weight: Int, age: Int) async throws {
        let data: [String: Any] = [
            "nickname": nickname,
            "height": height,
            "weight": weight,
            "age": age,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("users").document(uid).setData(data, merge: true)
    }

    // MARK: - 프로필 조회
    func fetchUserProfile(uid: String) async throws -> [String: Any] {
        let doc = try await db.collection("users").document(uid).getDocument()
        return doc.data() ?? [:]
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
            guard
                let ts = d["startedAt"] as? Timestamp,
                let duration = d["duration"] as? Int,
                let distance = d["distance"] as? Double,
                let avgPace = d["avgPace"] as? Double
            else { return nil }

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
}
