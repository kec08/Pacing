import FirebaseAuth
import FirebaseMessaging
import Combine
import UserNotifications
import UIKit
import os

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    private let repository: NotificationDeviceRepository = FirestoreNotificationDeviceRepository.shared
    private let installationID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pacing.app", category: "PushNotification")

    func configure() {
        Messaging.messaging().delegate = self
        logger.debug("FCM delegate configured")
    }

    func requestAuthorization() async {
        do {
            guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) else {
                logger.notice("Push authorization was not granted")
                return
            }
        } catch {
            logger.error("Push authorization request failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        logger.info("Push authorization granted; registering with APNs")
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// 기존 가입자는 온보딩 권한 화면을 다시 통과하지 않으므로, 메인 화면 진입 시
    /// 최초 한 번 권한을 요청하고 허용된 기기의 FCM 토큰을 항상 최신화한다.
    func activateForCurrentUser() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            await requestAuthorization()
        } else if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            logger.debug("Push authorization already granted; registering with APNs")
            UIApplication.shared.registerForRemoteNotifications()
        } else {
            logger.notice("Push authorization unavailable: \(settings.authorizationStatus.rawValue)")
        }
        synchronizeCurrentToken()
    }

    func didRegisterAPNSToken(_ token: Data) {
        Messaging.messaging().apnsToken = token
        logger.info("APNs token registered; synchronizing FCM token")
        synchronizeCurrentToken()
    }

    func didFailToRegisterForRemoteNotifications(with error: Error) {
        logger.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }

    func synchronizeToken(_ token: String?) {
        guard let uid = Auth.auth().currentUser?.uid else {
            logger.notice("FCM token unavailable for storage because no authenticated user exists")
            return
        }
        guard let token, !token.isEmpty else {
            logger.error("FCM token is empty")
            return
        }

        Task {
            do {
                try await repository.save(token: token, installationID: installationID, uid: uid)
                logger.info("FCM token synchronized to Firestore")
            } catch {
                logger.error("FCM token Firestore synchronization failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func synchronizeCurrentToken() {
        Messaging.messaging().register { [weak self] token, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.logger.error("FCM token retrieval failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                self.synchronizeToken(token)
            }
        }
    }
}

extension NotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.logger.info("FCM registration token refreshed")
            self.synchronizeToken(fcmToken)
        }
    }
}
