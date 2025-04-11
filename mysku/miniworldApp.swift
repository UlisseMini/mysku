// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org

import SwiftUI
import UserNotifications

@main
struct miniworldApp: App {
    @UIApplicationDelegateAdaptor(NotificationHandler.self) var notificationHandler
    
    init() {
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
    
    private func setupForUITests() {
        // Reset user defaults if needed
        if ProcessInfo.processInfo.arguments.contains("-ResetUserDefaults") {
            print("🧪 Resetting UserDefaults for testing")
            let domain = Bundle.main.bundleIdentifier!
            UserDefaults.standard.removePersistentDomain(forName: domain)
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
