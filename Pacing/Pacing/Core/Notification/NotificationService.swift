import FirebaseAuth
import FirebaseMessaging
import Combine
import UserNotifications
import UIKit

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    private let repository: NotificationDeviceRepository = FirestoreNotificationDeviceRepository.shared
    private let installationID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

    func configure() { Messaging.messaging().delegate = self }

    func requestAuthorization() async {
        guard (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) == true else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// 기존 가입자는 온보딩 권한 화면을 다시 통과하지 않으므로, 메인 화면 진입 시
    /// 최초 한 번 권한을 요청하고 허용된 기기의 FCM 토큰을 항상 최신화한다.
    func activateForCurrentUser() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            await requestAuthorization()
        } else if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
        synchronizeCurrentToken()
    }

    func synchronizeToken(_ token: String?) {
        guard let uid = Auth.auth().currentUser?.uid, let token, !token.isEmpty else { return }
        Task { try? await repository.save(token: token, installationID: installationID, uid: uid) }
    }

    func synchronizeCurrentToken() {
        Messaging.messaging().token { [weak self] token, _ in
            Task { @MainActor in self?.synchronizeToken(token) }
        }
    }
}

extension NotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in self.synchronizeToken(fcmToken) }
    }
}
