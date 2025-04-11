import SwiftUI
import UserNotifications

@main
struct miniworldApp: App {
    @UIApplicationDelegateAdaptor(NotificationHandler.self) var notificationHandler
    
    init() {
        print("🏁 miniworldApp init() entered.")
        print("Arguments received: \(ProcessInfo.processInfo.arguments)")
        
        // Check if running UI tests
        if ProcessInfo.processInfo.arguments.contains("-UITests") {
            print("🧪 Running in UI Test mode")
            setupForUITests()
        }
        
        // Log backend URL
        print("🌐 Backend URL: \(Constants.backendURL)")
        
        // Configure URL session
        URLSession.shared.configuration.httpCookieStorage?.cookieAcceptPolicy = .always
        
        // Request notification authorization
        print("🔔 miniworldApp: Requesting notification authorization...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("🔔 miniworldApp: Failed to request notification authorization: \(error.localizedDescription)")
                return
            }
            
            print("🔔 miniworldApp: Notification authorization granted: \(granted)")
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
    
    private func setupForUITests() {
        // Check for the full reset flag
        if ProcessInfo.processInfo.arguments.contains("-ResetState") {
            print("🧪 Resetting application state for UI Tests...")
            
            // 1. Clear UserDefaults
            let domain = Bundle.main.bundleIdentifier!
            UserDefaults.standard.removePersistentDomain(forName: domain)
            print("  -> UserDefaults cleared.")
            
            // 2. Perform Logout (Add other state clearing as needed)
            AuthManager.shared.logout() 
            print("  -> AuthManager logout called.")
            
            // 3. Clear Keychain data if necessary
            // KeychainManager.shared.clearSensitiveData()
            // print("  -> Keychain cleared (if implemented).")

            // 4. Clear database data if necessary
            // DatabaseManager.shared.deleteAllData()
            // print("  -> Database cleared (if implemented).")

            UserDefaults.standard.synchronize()
            print("🧪 Application state reset complete.")
        } else {
            print("🧪 UI Test mode active, but '-ResetState' argument NOT found.")
        }
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
