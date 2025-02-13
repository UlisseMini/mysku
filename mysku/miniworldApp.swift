//
//  miniworldApp.swift
//  miniworld
//
//  Created by Ulisse Mini on 1/26/25.
//

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
                    if url.scheme == "miniworld" {
                        AuthManager.shared.handleCallback(url: url)
                    }
                }
        }
    }
}
