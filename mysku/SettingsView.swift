import SwiftUI

// MARK: - Design System
struct AppTheme {
    // Colors
    static let primaryColor = Color.blue
    static let secondaryColor = Color(.systemGray5)
    static let accentColor = Color.blue
    static let destructiveColor = Color.red
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)
    static let backgroundPrimary = Color(.systemBackground)
    static let backgroundSecondary = Color(.secondarySystemBackground)
    static let cardBackground = Color(.tertiarySystemBackground)
    
    // Text Styles
    static func title(_ text: Text) -> some View {
        text
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(textPrimary)
    }
    
    static func heading(_ text: Text) -> some View {
        text
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(primaryColor)
            .textCase(nil)
    }
    
    static func sectionHeader(_ text: Text) -> some View {
        text
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(primaryColor)
            .textCase(nil)
            .padding(.bottom, 4)
    }
    
    static func caption(_ text: Text) -> some View {
        text
            .font(.footnote)
            .foregroundColor(textSecondary)
            .padding(.top, 4)
    }
    
    // Card Styles
    static func card<Content: View>(_ content: Content) -> some View {
        content
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // Custom Toggle Style
    struct CustomToggleStyle: ToggleStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack {
                configuration.label
                    .font(.body)
                
                Spacer()
                
                ZStack {
                    Capsule()
                        .fill(configuration.isOn ? primaryColor : Color(.systemGray4))
                        .frame(width: 50, height: 30)
                    
                    Circle()
                        .fill(Color.white)
                        .shadow(radius: 1)
                        .frame(width: 26, height: 26)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.spring(response: 0.2), value: configuration.isOn)
                }
                .onTapGesture {
                    withAnimation {
                        configuration.isOn.toggle()
                    }
                }
            }
            .contentShape(Rectangle())
        }
    }
    
    // Custom Picker Row
    struct PickerRowStyle: ViewModifier {
        var value: String
        
        func body(content: Content) -> some View {
            HStack {
                content
                    .font(.body)
                Spacer()
                HStack(spacing: 6) {
                    Text(value)
                        .foregroundColor(primaryColor)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(primaryColor)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
    }
    
    // Custom Button Styles
    struct PrimaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.body.weight(.medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(primaryColor)
                        .opacity(configuration.isPressed ? 0.8 : 1.0)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
        }
    }
    
    struct DestructiveButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.body.weight(.medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(destructiveColor)
                        .opacity(configuration.isPressed ? 0.8 : 1.0)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
        }
    }
}

// MARK: - Extensions for Theme Styles
extension Text {
    func title() -> some View {
        AppTheme.title(self)
    }
    
    func heading() -> some View {
        AppTheme.heading(self)
    }
    
    func sectionHeader() -> some View {
        AppTheme.sectionHeader(self)
    }
    
    func caption() -> some View {
        AppTheme.caption(self)
    }
}

extension Toggle {
    func customToggleStyle() -> some View {
        self.toggleStyle(AppTheme.CustomToggleStyle())
    }
}

extension View {
    func withPickerRow(value: String) -> some View {
        self.modifier(AppTheme.PickerRowStyle(value: value))
    }
    
    func asCard() -> some View {
        AppTheme.card(self)
    }
}

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
        HStack(spacing: 14) {
            AsyncImage(url: guild.iconURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.secondaryColor, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "server.rack")
                            .foregroundColor(Color.gray.opacity(0.5))
                    )
            }
            
            Text(guild.name)
                .font(.body)
                .fontWeight(isEnabled ? .medium : .regular)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(isEnabled ? AppTheme.textPrimary : AppTheme.textSecondary)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .tint(AppTheme.primaryColor)
            .scaleEffect(0.9)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
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
        HStack(spacing: 14) {
            AsyncImage(url: user.duser.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.secondaryColor, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(Color.gray.opacity(0.5))
                    )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(user.duser.username)
                    .font(.body)
                    .fontWeight(isCurrentUser ? .semibold : .regular)
                    .lineLimit(1)
                    .foregroundColor(isBlocked ? AppTheme.textSecondary : AppTheme.textPrimary)
                
                if isCurrentUser {
                    Text("You")
                        .font(.caption)
                        .foregroundColor(AppTheme.primaryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.primaryColor.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            if !isCurrentUser {
                Button(action: onToggleBlock) {
                    Text(isBlocked ? "Unblock" : "Block")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isBlocked ? AppTheme.primaryColor : AppTheme.destructiveColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isBlocked ? AppTheme.primaryColor.opacity(0.1) : AppTheme.destructiveColor.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isBlocked ? AppTheme.primaryColor.opacity(0.2) : AppTheme.destructiveColor.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .opacity(isCurrentUser ? 1.0 : (isBlocked ? 0.7 : 1.0))
        .animation(.easeOut(duration: 0.2), value: isBlocked)
    }
}

// MARK: - Location Settings View
private struct LocationSettingsView: View {
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        Section {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(AppTheme.primaryColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(AppTheme.primaryColor.opacity(0.1))
                                .frame(width: 36, height: 36)
                        )
                    
                    Toggle("Background Updates", isOn: $locationManager.backgroundUpdatesEnabled)
                        .tint(AppTheme.primaryColor)
                }
                .padding(.vertical, 4)
                
                if locationManager.backgroundUpdatesEnabled {
                    Divider()
                        .padding(.horizontal, 8)
                    
                    VStack(spacing: 16) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(AppTheme.primaryColor)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(AppTheme.primaryColor.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                    )
                                
                                Text("Update Interval")
                                    .font(.body)
                                
                                Spacer()
                                
                                Picker("", selection: $locationManager.updateInterval) {
                                    Text("30 seconds").tag(30.0)
                                    Text("1 minute").tag(60.0)
                                    Text("5 minutes").tag(300.0)
                                    Text("15 minutes").tag(900.0)
                                    Text("30 minutes").tag(1800.0)
                                    Text("1 hour").tag(3600.0)
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .accentColor(AppTheme.primaryColor)
                            }
                            .withPickerRow(value: getIntervalText(locationManager.updateInterval))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "arrow.up.and.down")
                                    .foregroundColor(AppTheme.primaryColor)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(AppTheme.primaryColor.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                    )
                                
                                Text("Minimum Movement")
                                    .font(.body)
                                
                                Spacer()
                                
                                Picker("", selection: $locationManager.minimumMovementThreshold) {
                                    Text("100m").tag(100.0)
                                    Text("500m").tag(500.0)
                                    Text("1km").tag(1000.0)
                                    Text("5km").tag(5000.0)
                                    Text("10km").tag(10000.0)
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .accentColor(AppTheme.primaryColor)
                            }
                            .withPickerRow(value: getDistanceText(locationManager.minimumMovementThreshold))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
                
                Divider()
                    .padding(.horizontal, 8)
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "eye.slash")
                            .foregroundColor(AppTheme.primaryColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(AppTheme.primaryColor.opacity(0.1))
                                    .frame(width: 36, height: 36)
                            )
                        
                        Text("Location Privacy")
                            .font(.body)
                        
                        Spacer()
                        
                        Picker("", selection: $locationManager.desiredAccuracy) {
                            Text("Full Accuracy").tag(0.0)
                            Text("1 km").tag(1000.0)
                            Text("5 km").tag(5000.0)
                            Text("10 km").tag(10000.0)
                            Text("100 km").tag(100000.0)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .accentColor(AppTheme.primaryColor)
                    }
                    .withPickerRow(value: getAccuracyText(locationManager.desiredAccuracy))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.vertical, 4)
            }
            .padding(.vertical, 8)
        } header: {
            Text("LOCATION SETTINGS")
                .sectionHeader()
        }
    }
    
    private func getIntervalText(_ interval: TimeInterval) -> String {
        switch interval {
        case 30.0: return "30 seconds"
        case 60.0: return "1 minute"
        case 300.0: return "5 minutes"
        case 900.0: return "15 minutes"
        case 1800.0: return "30 minutes"
        case 3600.0: return "1 hour"
        default: return "\(Int(interval)) seconds"
        }
    }
    
    private func getDistanceText(_ distance: Double) -> String {
        if distance >= 1000 {
            let km = distance / 1000.0
            return "\(Int(km)) km"
        } else {
            return "\(Int(distance)) m"
        }
    }
    
    private func getAccuracyText(_ accuracy: Double) -> String {
        if accuracy == 0 {
            return "Full Accuracy"
        } else if accuracy >= 1000 {
            let km = accuracy / 1000.0
            return "\(Int(km)) km"
        } else {
            return "\(Int(accuracy)) m"
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
            VStack(spacing: 20) {
                // Simple logout button with enhanced accessibility
                Button("Logout") {
                    authManager.logout()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(8)
                .padding(.horizontal)
                .accessibility(identifier: "Logout")
                .accessibilityLabel("Logout")
                
                // Delete data button
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete My Data")
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        } header: {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.blue)
                Text("ACCOUNT")
                    .font(.headline)
                    .foregroundColor(.blue)
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
            if isLoading || isSaving {
                // Background blur
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                // Loading card
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(AppTheme.secondaryColor, lineWidth: 4)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 0, to: 0.75)
                            .stroke(AppTheme.primaryColor, lineWidth: 4)
                            .frame(width: 50, height: 50)
                            .rotationEffect(Angle(degrees: isLoading ? 360 : 0))
                            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
                    }
                    
                    Text(isLoading ? "Loading..." : "Saving...")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.backgroundPrimary)
                        .opacity(0.95)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
                .frame(width: 200)
                .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 6)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(), value: isLoading || isSaving)
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
                HStack {
                    Image(systemName: "rectangle.stack.badge.person.crop")
                        .foregroundColor(AppTheme.primaryColor)
                        .font(.footnote)
                    Text("DISCORD SERVERS")
                        .sectionHeader()
                }
            }
            .listSectionSpacing(.compact)
            
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
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(AppTheme.primaryColor)
                        .font(.footnote)
                    Text("USERS")
                        .sectionHeader()
                }
            }
            .listSectionSpacing(.compact)
            
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
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(AppTheme.primaryColor)
                        .font(.footnote)
                    Text("LOCATION SETTINGS")
                        .sectionHeader()
                }
            } footer: {
                if locationManager.backgroundUpdatesEnabled {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppTheme.textSecondary)
                            .font(.caption)
                        Text("Background updates allow your location to be shared even when the app is closed.")
                            .font(.footnote)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.top, 4)
                }
            }
            .listSectionSpacing(.compact)
            
            // Notifications Section - UPDATED
            NotificationSettingsView(
                receiveNearbyNotifications: $receiveNearbyNotifications,
                nearbyNotificationDistance: $nearbyNotificationDistance,
                allowNearbyNotifications: $allowNearbyNotifications,
                allowNearbyNotificationDistance: $allowNearbyNotificationDistance,
                notificationDistanceOptions: notificationDistanceOptions,
                saveUserSettings: saveUserSettings
            )
            
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