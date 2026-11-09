import FirebaseFirestore

protocol NotificationDeviceRepository {
    func save(token: String, installationID: String, uid: String) async throws
}

final class FirestoreNotificationDeviceRepository: NotificationDeviceRepository {
    static let shared = FirestoreNotificationDeviceRepository()
    private let database = Firestore.firestore()
    private init() {}

    func save(token: String, installationID: String, uid: String) async throws {
        guard !token.isEmpty, !installationID.isEmpty, !uid.isEmpty else { return }
        try await database.collection("users").document(uid).collection("notificationDevices").document(installationID).setData([
            "token": token, "platform": "ios", "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
}
