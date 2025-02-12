import SwiftUI
import OAuthSwift

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var errorMessage: String?
    @State private var selectedGuilds: Set<String> = []
    @State private var blockedUsers: [String] = []
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Discord Servers")) {
                    if authManager.guilds.isEmpty {
                        Text("Loading servers...")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(authManager.guilds) { guild in
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
                                        savePrivacySettings()
                                    }
                                ))
                            }
                            .padding(.vertical, 4)
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
                do {
                    try await authManager.fetchGuilds()
                } catch {
                    errorMessage = error.localizedDescription
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
    
    private func savePrivacySettings() {
        Task {
            isSaving = true
            do {
                try await authManager.updatePrivacySettings(
                    enabledGuilds: Array(selectedGuilds),
                    blockedUsers: blockedUsers
                )
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
} 