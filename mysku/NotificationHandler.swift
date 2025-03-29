import UIKit
import UserNotifications

class NotificationHandler: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let tokenKey = "push_token"
    
    override init() {
        super.init()
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("🔔 NotificationHandler: Successfully registered for remote notifications")
        print("🔔 NotificationHandler: Device token:", token)
        
        // Store the token
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔔 NotificationHandler: Failed to register for remote notifications:", error)
    }
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 NotificationHandler: Received notification in foreground")
        print("🔔 NotificationHandler: Notification content:", notification.request.content)
        completionHandler([.alert, .badge, .sound])
    }
} 