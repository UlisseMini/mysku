import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var apiManager = APIManager.shared
    @State private var errorMessage: String?
    @State private var selectedGuilds: Set<String> = []
    @State private var blockedUsers: [String] = []
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Discord Servers")) {
                    if apiManager.guilds.isEmpty {
                        Text("Loading servers...")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(apiManager.guilds) { guild in
                            HStack {
                                if let iconURL = guild.iconURL {
                                    AsyncImage(url: iconURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 40, height: 40)
                                    }
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                }
                                
                                Text(guild.name)
                                    .padding(.leading, 8)
                                
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
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section(header: Text("Users")) {
                    if apiManager.users.isEmpty {
                        Text("Loading users...")
                            .foregroundColor(.gray)
                    } else {
                        let filteredUsers = apiManager.users.filter { user in
                            user.id != apiManager.currentUser?.id
                        }
                        
                        let sortedUsers = filteredUsers.sorted { user1, user2 in
                            // Put blocked users at the bottom
                            let isBlocked1 = blockedUsers.contains(user1.id)
                            let isBlocked2 = blockedUsers.contains(user2.id)
                            if isBlocked1 != isBlocked2 {
                                return !isBlocked1
                            }
                            return user1.duser.username < user2.duser.username
                        }
                        
                        if filteredUsers.isEmpty {
                            Text("No other users found")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(sortedUsers, id: \.id) { user in
                                HStack {
                                    // User avatar
                                    if let avatar = user.duser.avatar {
                                        AsyncImage(url: URL(string: "https://cdn.discordapp.com/avatars/\(user.id)/\(avatar).png")) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        } placeholder: {
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 40, height: 40)
                                        }
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 40, height: 40)
                                    }
                                    
                                    Text(user.duser.username)
                                        .padding(.leading, 8)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        if blockedUsers.contains(user.id) {
                                            blockedUsers.removeAll { $0 == user.id }
                                        } else {
                                            blockedUsers.append(user.id)
                                        }
                                        saveUserSettings()
                                    }) {
                                        Text(blockedUsers.contains(user.id) ? "Unblock" : "Block")
                                            .foregroundColor(blockedUsers.contains(user.id) ? .blue : .red)
                                    }
                                }
                                .padding(.vertical, 4)
                                .opacity(blockedUsers.contains(user.id) ? 0.6 : 1.0)
                            }
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: {
                        authManager.logout()
                    }) {
                        Text("Logout")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                await loadData()
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
    
    private func loadData() async {
        do {
            // Fetch guilds, users, and current user in parallel
            async let guildsTask = apiManager.fetchGuilds()
            async let usersTask = apiManager.fetchUsers()
            async let userTask = apiManager.fetchCurrentUser()
            
            try await guildsTask
            try await usersTask
            try await userTask
            
            // Update UI with user settings
            if let user = apiManager.currentUser {
                selectedGuilds = Set(user.privacy.enabledGuilds)
                blockedUsers = user.privacy.blockedUsers
            }
            
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func saveUserSettings() {
        guard let currentUser = apiManager.currentUser else { return }
        
        Task {
            isSaving = true
            do {
                // Create updated user with new privacy settings
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
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
} 