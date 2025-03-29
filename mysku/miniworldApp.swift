import SwiftUI
import UserNotifications

@main
struct miniworldApp: App {
    @UIApplicationDelegateAdaptor(NotificationHandler.self) var notificationHandler
    
    init() {
        // Log backend URL
        print("🌐 Backend URL: \(Constants.backendURL)")
        
        // Configure URL session
        URLSession.shared.configuration.httpCookieStorage?.cookieAcceptPolicy = .always
        
        // Request notification authorization
        print("🔔 miniworldApp: Requesting notification authorization...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("🔔 miniworldApp: Failed to request notification authorization:", error)
                return
            }
            
            print("🔔 miniworldApp: Notification authorization granted:", granted)
            if granted {
                DispatchQueue.main.async {
                    print("🔔 miniworldApp: Registering for remote notifications...")
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        
        // Set notification center delegate
        print("🔔 miniworldApp: Setting notification center delegate")
        UNUserNotificationCenter.current().delegate = notificationHandler
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle OAuth callback URL
                    if url.scheme == "mysku" {
                        AuthManager.shared.handleCallback(url: url)
                    }
                }
        }
    }
}
