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
}
