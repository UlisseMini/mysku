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

// MARK: - Location Settings View
private struct LocationSettingsView: View {
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        Section(header: Text("Location Settings")) {
            Toggle("Background Updates", isOn: $locationManager.backgroundUpdatesEnabled)
            
            if locationManager.backgroundUpdatesEnabled {
                Picker("Update Interval", selection: $locationManager.updateInterval) {
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                    Text("15 minutes").tag(900.0)
                    Text("30 minutes").tag(1800.0)
                    Text("1 hour").tag(3600.0)
                }
                .pickerStyle(.menu)
                
                Picker("Minimum Movement", selection: $locationManager.minimumMovementThreshold) {
                    Text("100m").tag(100.0)
                    Text("500m").tag(500.0)
                    Text("1km").tag(1000.0)
                    Text("5km").tag(5000.0)
                    Text("10km").tag(10000.0)
                }
                .pickerStyle(.menu)
            }
            
            Picker("Location Privacy", selection: $locationManager.desiredAccuracy) {
                Text("Full Accuracy").tag(0.0)
                Text("1 km").tag(1000.0)
                Text("5 km").tag(5000.0)
                Text("10 km").tag(10000.0)
                Text("100 km").tag(100000.0)
            }
            .pickerStyle(.menu)
        }
    }
}

// MARK: - Account Actions View
private struct AccountActionsView: View {
    @ObservedObject var authManager: AuthManager
    @Binding var showingDeleteConfirmation: Bool
    let deleteUserDataAndLogout: () -> Void
    
    var body: some View {
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
}

// MARK: - Loading Overlay View
private struct LoadingOverlayView: View {
    let isLoading: Bool
    let isSaving: Bool
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
            
            if isSaving {
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
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
    @Binding var showingDeleteConfirmation: Bool
    @Binding var receiveNearbyNotifications: Bool
    @Binding var allowNearbyNotifications: Bool
    @Binding var nearbyNotificationDistance: Double
    @Binding var allowNearbyNotificationDistance: Double
    let refreshIntervals: [TimeInterval: String]
    let saveUserSettings: () -> Void
    let deleteUserDataAndLogout: () -> Void
    
    // Distance options and their display values for Location Privacy
    private let locationDistanceOptions: [(value: Double, display: String)] = [
        (0.0, "Full Accuracy"),
        (1000.0, "1 km"),
        (5000.0, "5 km"),
        (10000.0, "10 km"),
        (100000.0, "100 km")
    ]
    
    // Distance options for Nearby Notifications
    private let notificationDistanceOptions: [(value: Double, display: String)] = [
        (50.0, "50 meters"),
        (100.0, "100 meters"),
        (250.0, "250 meters"),
        (500.0, "500 meters"),
        (1000.0, "1 kilometer")
    ]
    
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
                LocationSettingsView(locationManager: locationManager)
            } header: {
                Text("LOCATION SETTINGS")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .textCase(nil)
            } footer: {
                if locationManager.backgroundUpdatesEnabled {
                    Text("Background updates allow your location to be shared even when the app is closed.")
                }
            }
            
            // Notifications Section - UPDATED
            Section {
                Toggle("Notify me when I'm near someone", isOn: $receiveNearbyNotifications)
                    .onChange(of: receiveNearbyNotifications) { _ in saveUserSettings() }
                
                // Conditional Picker for nearby notification distance
                if receiveNearbyNotifications {
                    Picker("Notification Distance", selection: $nearbyNotificationDistance) {
                        ForEach(notificationDistanceOptions, id: \.value) { option in
                            Text(option.display).tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: nearbyNotificationDistance) { _ in saveUserSettings() }
                }
                
                Toggle("Notify others when they are near me", isOn: $allowNearbyNotifications)
                    .onChange(of: allowNearbyNotifications) { _ in saveUserSettings() }

                // Conditional Picker for allowing nearby notification distance
                if allowNearbyNotifications {
                    Picker("Notify Others Within", selection: $allowNearbyNotificationDistance) {
                        ForEach(notificationDistanceOptions, id: \.value) { option in
                            Text(option.display).tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: allowNearbyNotificationDistance) { _ in saveUserSettings() }
                }

            } header: {
                Text("NEARBY NOTIFICATIONS")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .textCase(nil)
            } footer: {
                Text("Receive a push notification when another user you share a server with is nearby. Define the distance for receiving notifications and for allowing others to be notified about you.")
            }

            // Account Actions Section
            AccountActionsView(
                authManager: authManager,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                deleteUserDataAndLogout: deleteUserDataAndLogout
            )
        }
        .task {
            if apiManager.currentUser == nil {
                await apiManager.loadInitialData()
            }
            
            if let user = apiManager.currentUser {
                selectedGuilds = Set(user.privacy.enabledGuilds)
                blockedUsers = user.privacy.blockedUsers
                receiveNearbyNotifications = user.receiveNearbyNotifications ?? true
                allowNearbyNotifications = user.allowNearbyNotifications ?? true
                // Load distance values, using 500m as default if nil
                nearbyNotificationDistance = user.nearbyNotificationDistance ?? 500.0
                allowNearbyNotificationDistance = user.allowNearbyNotificationDistance ?? 500.0
            }
        }
        .overlay {
            LoadingOverlayView(isLoading: apiManager.isLoading, isSaving: isSaving)
        }
        .alert("Delete Account Data", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteUserDataAndLogout()
            }
        } message: {
            Text("This will permanently delete all your data including location history and preferences. This action cannot be undone.")
        }
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
    @State private var showingDeleteConfirmation = false
    @State private var receiveNearbyNotifications: Bool = true
    @State private var allowNearbyNotifications: Bool = true
    @State private var nearbyNotificationDistance: Double = 500.0
    @State private var allowNearbyNotificationDistance: Double = 500.0
    
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
                showingDeleteConfirmation: $showingDeleteConfirmation,
                receiveNearbyNotifications: $receiveNearbyNotifications,
                allowNearbyNotifications: $allowNearbyNotifications,
                nearbyNotificationDistance: $nearbyNotificationDistance,
                allowNearbyNotificationDistance: $allowNearbyNotificationDistance,
                refreshIntervals: refreshIntervals,
                saveUserSettings: saveUserSettings,
                deleteUserDataAndLogout: deleteUserDataAndLogout
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
                    showingDeleteConfirmation: $showingDeleteConfirmation,
                    receiveNearbyNotifications: $receiveNearbyNotifications,
                    allowNearbyNotifications: $allowNearbyNotifications,
                    nearbyNotificationDistance: $nearbyNotificationDistance,
                    allowNearbyNotificationDistance: $allowNearbyNotificationDistance,
                    refreshIntervals: refreshIntervals,
                    saveUserSettings: saveUserSettings,
                    deleteUserDataAndLogout: deleteUserDataAndLogout
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
                    ),
                    pushToken: UserDefaults.standard.string(forKey: "push_token"),
                    receiveNearbyNotifications: receiveNearbyNotifications,
                    allowNearbyNotifications: allowNearbyNotifications,
                    nearbyNotificationDistance: nearbyNotificationDistance,
                    allowNearbyNotificationDistance: allowNearbyNotificationDistance
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