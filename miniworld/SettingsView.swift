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
            if let iconURL = guild.iconURL {
                AsyncImage(url: iconURL) { image in
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
            } else {
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
            if let avatar = user.duser.avatar {
                AsyncImage(url: URL(string: "https://cdn.discordapp.com/avatars/\(user.id)/\(avatar).png")) { image in
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
            } else {
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
    @State private var selectedGuilds: Set<String> = []
    @State private var blockedUsers: [String] = []
    @State private var isSaving = false
    @State private var guildSearchText = ""
    @State private var userSearchText = ""
    @State private var privacyRadius: Double = UserDefaults.standard.double(forKey: "privacyRadius")
    
    // Refresh interval options in seconds
    private let refreshIntervals = [
        15.0: "15 seconds",
        30.0: "30 seconds",
        60.0: "1 minute",
        300.0: "5 minutes"
    ]
    
    var body: some View {
        NavigationView {
            SettingsListContent(
                authManager: authManager,
                apiManager: apiManager,
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
    @Binding var selectedGuilds: Set<String>
    @Binding var blockedUsers: [String]
    @Binding var isSaving: Bool
    @Binding var guildSearchText: String
    @Binding var userSearchText: String
    @Binding var privacyRadius: Double
    let refreshIntervals: [TimeInterval: String]
    let saveUserSettings: () -> Void
    
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
            
            // Privacy Settings Section
            Section {
                let privacyRadiusOptions = [
                    0: "No privacy radius",
                    1000: "1 km",
                    2000: "2 km",
                    5000: "5 km",
                    10000: "10 km",
                    25000: "25 km",
                    100000: "100 km"
                ]
                
                Picker("Privacy Radius", selection: Binding(
                    get: { privacyRadius },
                    set: { newRadius in
                        privacyRadius = newRadius
                        UserDefaults.standard.set(newRadius, forKey: "privacyRadius")
                        Task {
                            do {
                                try await LocationManager.shared.requestLocationUpdate()
                                await apiManager.loadInitialData()
                            } catch {
                                print("Failed to update location: \(error)")
                            }
                        }
                    }
                )) {
                    ForEach(Array(privacyRadiusOptions.keys.sorted()), id: \.self) { radius in
                        Text(privacyRadiusOptions[radius] ?? "\(Int(radius))m")
                            .tag(Double(radius))
                    }
                }
            } header: {
                Text("PRIVACY SETTINGS")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .textCase(nil)
            }
            
            // Refresh Settings Section
            Section {
                Picker("Refresh Interval", selection: Binding(
                    get: { apiManager.refreshInterval },
                    set: { apiManager.updateRefreshInterval($0) }
                )) {
                    ForEach(Array(refreshIntervals.keys.sorted()), id: \.self) { interval in
                        Text(refreshIntervals[interval] ?? "\(Int(interval))s")
                            .tag(interval)
                    }
                }
            } header: {
                Text("REFRESH SETTINGS")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .textCase(nil)
            }
            
            // Logout Section
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
        .refreshable {
            await apiManager.loadInitialData()
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
    }
} 