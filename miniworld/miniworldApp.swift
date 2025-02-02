//
//  miniworldApp.swift
//  miniworld
//
//  Created by Ulisse Mini on 1/26/25.
//

import SwiftUI
import OAuthSwift

@main
struct miniworldApp: App {
    init() {
        // Configure OAuth callback handling
        URLSession.shared.configuration.httpCookieStorage?.cookieAcceptPolicy = .always
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle OAuth callback URL
                    if url.scheme == "miniworld" {
                        OAuthSwift.handle(url: url)
                    }
                }
        }
    }
}
