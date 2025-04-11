// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        if authManager.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

#Preview {
    ContentView()
}
