import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var apiManager = APIManager.shared
    @State private var selectedGuilds: Set<String> = []
    @State private var blockedUsers: [String] = []
    @State private var isSaving = false
    @State private var guildSearchText = ""
    @State private var userSearchText = ""
    
    // Refresh interval options in seconds
    private let refreshIntervals = [
        15.0: "15 seconds",
        30.0: "30 seconds",
        60.0: "1 minute",
        300.0: "5 minutes"
    ]
    
    var filteredGuilds: [Guild] {
        let sortedGuilds = apiManager.guilds.sorted { guild1, guild2 in
            let isEnabled1 = selectedGuilds.contains(guild1.id)
            let isEnabled2 = selectedGuilds.contains(guild2.id)
            if isEnabled1 != isEnabled2 {
                return isEnabled1
            }
            return guild1.name < guild2.name
        }
        
        if guildSearchText.isEmpty {
            return sortedGuilds
        }
        return sortedGuilds.filter { guild in
            guild.name.localizedCaseInsensitiveContains(guildSearchText)
        }
    }
    
    var filteredUsers: [User] {
        let sortedUsers = apiManager.users.sorted { user1, user2 in
            let isBlocked1 = blockedUsers.contains(user1.id)
            let isBlocked2 = blockedUsers.contains(user2.id)
            if isBlocked1 != isBlocked2 {
                return !isBlocked1
            }
            return user1.duser.username < user2.duser.username
        }
        
        if userSearchText.isEmpty {
            return sortedUsers
        }
        return sortedUsers.filter { user in
            user.duser.username.localizedCaseInsensitiveContains(userSearchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    if apiManager.guilds.isEmpty {
                        Text("No servers available")
                            .foregroundColor(.gray)
                    } else {
                        FilterableListView(
                            items: filteredGuilds,
                            searchPlaceholder: "Search servers...",
                            searchText: $guildSearchText
                        ) { guild in
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
                                    get: { selectedGuilds.contains(guild.id) },
                                    set: { isEnabled in
                                        if isEnabled {
                                            selectedGuilds.insert(guild.id)
                                        } else {
                                            selectedGuilds.remove(guild.id)
                                        }
                                        saveUserSettings()
                                    }
                                ))
                                .tint(.accentColor)
                            }
                            .padding(.horizontal, 12)
                        }
                        .frame(minHeight: 100, maxHeight: min(CGFloat(filteredGuilds.count * 60 + 60), 450))
                        .listRowInsets(EdgeInsets())
                        .background(Color(uiColor: .systemBackground))
                    }
                } header: {
                    Text("DISCORD SERVERS")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .textCase(nil)
                }
                .padding(.bottom, 20)
                
                Section {
                    if apiManager.users.isEmpty {
                        Text("No users available")
                            .foregroundColor(.gray)
                    } else {
                        FilterableListView(
                            items: filteredUsers,
                            searchPlaceholder: "Search users...",
                            searchText: $userSearchText
                        ) { user in
                            let isCurrentUser = user.id == apiManager.currentUser?.id
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
                                    Button(action: {
                                        if blockedUsers.contains(user.id) {
                                            blockedUsers.removeAll { $0 == user.id }
                                        } else {
                                            blockedUsers.append(user.id)
                                        }
                                        saveUserSettings()
                                    }) {
                                        Text(blockedUsers.contains(user.id) ? "Unblock" : "Block")
                                            .font(.subheadline)
                                            .foregroundColor(blockedUsers.contains(user.id) ? .blue : .red)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .opacity(isCurrentUser ? 0.8 : (blockedUsers.contains(user.id) ? 0.6 : 1.0))
                        }
                        .frame(minHeight: 100, maxHeight: min(CGFloat(filteredUsers.count * 60 + 60), 450))
                        .listRowInsets(EdgeInsets())
                        .background(Color(uiColor: .systemBackground))
                    }
                } header: {
                    Text("USERS")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .textCase(nil)
                }
                
                if let error = apiManager.error {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
                
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
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground))
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