import Foundation

enum NotificationDestination: Equatable { case friends, running }

enum NotificationRouter {
    static func destination(from userInfo: [AnyHashable: Any]) -> NotificationDestination? {
        switch userInfo["type"] as? String {
        case "friendRequest": return .friends
        case "friendRunStarted", "dailyReminder", "inactivityReminder", "listenTogetherRequest": return .running
        default: return nil
        }
    }
}
