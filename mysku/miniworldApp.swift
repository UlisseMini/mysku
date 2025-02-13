import SwiftUI

@main
struct miniworldApp: App {
    init() {
        // Configure URL session
        URLSession.shared.configuration.httpCookieStorage?.cookieAcceptPolicy = .always
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
