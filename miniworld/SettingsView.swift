import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var apiManager = APIManager.shared
    @State private var selectedGuilds: Set<String> = []
    @State private var blockedUsers: [String] = []
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Discord Servers")) {
                    if apiManager.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    } else if apiManager.guilds.isEmpty {
                        Text("No servers available")
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
                    if apiManager.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    } else if apiManager.users.isEmpty {
                        Text("No users available")
                            .foregroundColor(.gray)
                    } else {
                        let sortedUsers = apiManager.users.sorted { user1, user2 in
                            // Put blocked users at the bottom
                            let isBlocked1 = blockedUsers.contains(user1.id)
                            let isBlocked2 = blockedUsers.contains(user2.id)
                            if isBlocked1 != isBlocked2 {
                                return !isBlocked1
                            }
                            return user1.duser.username < user2.duser.username
                        }
                        
                        ForEach(sortedUsers, id: \.id) { user in
                            let isCurrentUser = user.id == apiManager.currentUser?.id
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
                                
                                if isCurrentUser {
                                    Text("(You)")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 4)
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
                                            .foregroundColor(blockedUsers.contains(user.id) ? .blue : .red)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .opacity(isCurrentUser ? 0.6 : (blockedUsers.contains(user.id) ? 0.6 : 1.0))
                        }
                    }
                }
                
                if let error = apiManager.error {
                    Section {
                        Text(error.localizedDescription)
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
                // Load initial data if needed
                if apiManager.currentUser == nil {
                    apiManager.loadInitialData()
                }
                
                // Update UI with user settings
                if let user = apiManager.currentUser {
                    selectedGuilds = Set(user.privacy.enabledGuilds)
                    blockedUsers = user.privacy.blockedUsers
                }
            }
            .refreshable {
                apiManager.loadInitialData()
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
            } catch {
                // Error will be shown through APIManager.error
            }
            isSaving = false
        }
    }
} 