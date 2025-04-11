import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MapView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .tint(.blue) // Use a consistent blue tint for the tab bar
        .overlay(
            // Add a subtle top border to the tab bar
            VStack {
                Spacer()
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.systemGray5))
                    .padding(.bottom, 49) // Tab bar height
            }
        )
    }
} 