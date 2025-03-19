import SwiftUI

// MARK: - Server List View
struct ServerListView: View {
    let guilds: [Guild]
    let selectedGuilds: Set<String>
    let onToggle: (String, Bool) -> Void
    @Binding var searchText: String
    
    var filteredGuilds: [Guild] {
        let sortedGuilds = guilds.sorted { guild1, guild2 in
            let isEnabled1 = selectedGuilds.contains(guild1.id)
            let isEnabled2 = selectedGuilds.contains(guild2.id)
            if isEnabled1 != isEnabled2 {
                return isEnabled1
            }
            return guild1.name < guild2.name
        }
        
        if searchText.isEmpty {
            return sortedGuilds
        }
        return sortedGuilds.filter { guild in
            guild.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        if guilds.isEmpty {
            Text("No servers available")
                .foregroundColor(.gray)
        } else {
            FilterableListView(
                items: filteredGuilds,
                searchPlaceholder: "Search servers...",
                searchText: $searchText
            ) { guild in
                ServerRow(guild: guild, isEnabled: selectedGuilds.contains(guild.id)) { isEnabled in
                    onToggle(guild.id, isEnabled)
                }
            }
            .frame(minHeight: 100, maxHeight: min(CGFloat(filteredGuilds.count * 60 + 60), 450))
            .listRowInsets(EdgeInsets())
            .background(Color(uiColor: .systemBackground))
        }
    }
}

// MARK: - Server Row View
struct ServerRow: View {
    let guild: Guild
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: guild.iconURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
            }
            
            Text(guild.name)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .tint(.accentColor)
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - User List View
struct UserListView: View {
    let users: [User]
    let blockedUsers: [String]
    let currentUserId: String?
    let onToggleBlock: (String) -> Void
    @Binding var searchText: String
    
    var filteredUsers: [User] {
        let sortedUsers = users.sorted { user1, user2 in
            let isBlocked1 = blockedUsers.contains(user1.id)
            let isBlocked2 = blockedUsers.contains(user2.id)
            if isBlocked1 != isBlocked2 {
                return !isBlocked1
            }
            return user1.duser.username < user2.duser.username
        }
        
        if searchText.isEmpty {
            return sortedUsers
        }
        return sortedUsers.filter { user in
            user.duser.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        if users.isEmpty {
            Text("No users available")
                .foregroundColor(.gray)
        } else {
            FilterableListView(
                items: filteredUsers,
                searchPlaceholder: "Search users...",
                searchText: $searchText
            ) { user in
                UserRow(
                    user: user,
                    isBlocked: blockedUsers.contains(user.id),
                    isCurrentUser: user.id == currentUserId,
                    onToggleBlock: { onToggleBlock(user.id) }
                )
            }
            .frame(minHeight: 100, maxHeight: min(CGFloat(filteredUsers.count * 60 + 60), 450))
            .listRowInsets(EdgeInsets())
            .background(Color(uiColor: .systemBackground))
        }
    }
}

// MARK: - User Row View
struct UserRow: View {
    let user: User
    let isBlocked: Bool
    let isCurrentUser: Bool
    let onToggleBlock: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: user.duser.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.duser.username)
                    .fontWeight(isCurrentUser ? .medium : .regular)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                if isCurrentUser {
                    Text("You")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if !isCurrentUser {
                Button(action: onToggleBlock) {
                    Text(isBlocked ? "Unblock" : "Block")
                        .font(.subheadline)
                        .foregroundColor(isBlocked ? .blue : .red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 12)
        .opacity(isCurrentUser ? 0.8 : (isBlocked ? 0.6 : 1.0))
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var apiManager = APIManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @State private var selectedGuilds: Set<String> = []
    @State private var blockedUsers: [String] = []
    @State private var isSaving = false
    @State private var guildSearchText = ""
    @State private var userSearchText = ""
    @State private var privacyRadius: Double = UserDefaults.standard.double(forKey: "privacyRadius")
    
    // Refresh interval options in seconds
    private let refreshIntervals = [
        60.0: "1 minute",
        600.0: "10 minutes",
        3600.0: "1 hour",
        21600.0: "6 hours",
        86400.0: "1 day"
    ]
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Direct content for iPad
            SettingsListContent(
                authManager: authManager,
                apiManager: apiManager,
                locationManager: locationManager,
                selectedGuilds: $selectedGuilds,
                blockedUsers: $blockedUsers,
                isSaving: $isSaving,
                guildSearchText: $guildSearchText,
                userSearchText: $userSearchText,
                privacyRadius: $privacyRadius,
                refreshIntervals: refreshIntervals,
                saveUserSettings: saveUserSettings
            )
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground))
        } else {
            // Navigation view for iPhone
            NavigationView {
                SettingsListContent(
                    authManager: authManager,
                    apiManager: apiManager,
                    locationManager: locationManager,
                    selectedGuilds: $selectedGuilds,
                    blockedUsers: $blockedUsers,
                    isSaving: $isSaving,
                    guildSearchText: $guildSearchText,
                    userSearchText: $userSearchText,
                    privacyRadius: $privacyRadius,
                    refreshIntervals: refreshIntervals,
                    saveUserSettings: saveUserSettings
                )
                .navigationTitle("Settings")
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .systemBackground))
            }
        }
    }
    
    private func saveUserSettings() {
        guard let currentUser = apiManager.currentUser else { return }
        
        Task {
            isSaving = true
            do {
                let updatedUser = User(
                    id: currentUser.id,
                    location: currentUser.location,
                    duser: currentUser.duser,
                    privacy: PrivacySettings(
                        enabledGuilds: Array(selectedGuilds),
                        blockedUsers: blockedUsers
                    )
                )
                
                try await apiManager.updateCurrentUser(updatedUser)
                // Refresh data since enabled guilds/blocked users affect visible users
                await apiManager.loadInitialData()
            } catch {
                // Error will be shown through APIManager.error
            }
            isSaving = false
        }
    }
}

// MARK: - Settings List Content
private struct SettingsListContent: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var apiManager: APIManager
    @ObservedObject var locationManager: LocationManager
    @Binding var selectedGuilds: Set<String>
    @Binding var blockedUsers: [String]
    @Binding var isSaving: Bool
    @Binding var guildSearchText: String
    @Binding var userSearchText: String
    @Binding var privacyRadius: Double
    let refreshIntervals: [TimeInterval: String]
    let saveUserSettings: () -> Void
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        List {
            // Servers Section
            Section {
                ServerListView(
                    guilds: apiManager.guilds,
                    selectedGuilds: selectedGuilds,
                    onToggle: { guildId, isEnabled in
                        if isEnabled {
                            selectedGuilds.insert(guildId)
                        } else {
                            selectedGuilds.remove(guildId)
                        }
                        saveUserSettings()
                    },
                    searchText: $guildSearchText
                )
            } header: {
                Text("DISCORD SERVERS")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .textCase(nil)
            }
            .padding(.bottom, 20)
            
            // Users Section
            Section {
                UserListView(
                    users: apiManager.users,
                    blockedUsers: blockedUsers,
                    currentUserId: apiManager.currentUser?.id,
                    onToggleBlock: { userId in
                        if blockedUsers.contains(userId) {
                            blockedUsers.removeAll { $0 == userId }
                        } else {
                            blockedUsers.append(userId)
                        }
                        saveUserSettings()
                    },
                    searchText: $userSearchText
                )
            } header: {
                Text("USERS")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .textCase(nil)
            }
            
            // Error Section
            if let error = apiManager.error {
                Section {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
            }
            
            // Location Settings Section
            Section {
                if locationManager.authorizationStatus == .authorizedAlways {
                    Toggle("Background Location Updates", isOn: $locationManager.backgroundUpdatesEnabled)
                        .onChange(of: locationManager.backgroundUpdatesEnabled) { _ in
                            // The property observer in LocationManager will handle saving
                        }
                    
                    if locationManager.backgroundUpdatesEnabled {
                        Picker("Update Interval", selection: $locationManager.updateInterval) {
                            ForEach(Array(refreshIntervals.keys.sorted()), id: \.self) { interval in
                                Text(refreshIntervals[interval] ?? "\(Int(interval))s")
                                    .tag(interval)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Background Location Disabled")
                            .font(.headline)
                        
                        Text("Enable 'Always' location permission to allow background updates.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Request Background Permission") {
                            locationManager.requestAlwaysAuthorization()
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("LOCATION SETTINGS")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .textCase(nil)
            } footer: {
                if locationManager.backgroundUpdatesEnabled {
                    Text("Background updates allow your location to be shared even when the app is closed. This uses more battery but keeps your location current.")
                }
            }
            
            // Logout and Delete Section
            Section {
                Button(action: {
                    authManager.logout()
                }) {
                    HStack {
                        Text("Logout")
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Text("Delete My Data")
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .task {
            if apiManager.currentUser == nil {
                await apiManager.loadInitialData()
            }
            
            if let user = apiManager.currentUser {
                selectedGuilds = Set(user.privacy.enabledGuilds)
                blockedUsers = user.privacy.blockedUsers
            }
        }
        .overlay(alignment: .top) {
            if apiManager.isLoading {
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
        }
        .overlay(Group {
            if isSaving {
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
        })
        .alert("Delete Account Data", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteUserDataAndLogout()
            }
        } message: {
            Text("This will permanently delete all your data including location history and preferences. This action cannot be undone.")
        }
    }
    
    private func deleteUserDataAndLogout() {
        Task {
            do {
                try await apiManager.deleteUserData()
                await MainActor.run {
                    authManager.logout()
                }
            } catch {
                print("Error deleting user data:", error)
            }
        }
    }
} 