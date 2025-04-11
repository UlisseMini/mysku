// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org

import Foundation

// MARK: - Models

struct Location: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double      // Actual GPS accuracy in meters
    let desiredAccuracy: Double? // User's desired privacy-preserving accuracy in meters
    let lastUpdated: TimeInterval // Unix timestamp in milliseconds
    
    var formattedTimeSinceUpdate: String {
        let now = Date().timeIntervalSince1970 * 1000 // Convert to milliseconds
        let diff = now - lastUpdated
        
        // Convert to seconds
        let seconds = Int(diff / 1000)
        
        if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}

struct PrivacySettings: Codable {
    let enabledGuilds: [String]
    let blockedUsers: [String]
}

struct DiscordUser: Codable {
    let id: String
    let username: String
    let avatar: String?
    
    var avatarURL: URL? {
        let url: URL?
        if let avatar = avatar {
            url = URL(string: "https://cdn.discordapp.com/avatars/\(id)/\(avatar).png")
        } else {
            // Default avatar URL based on user ID
            let defaultIndex = (Int(id) ?? 0) % 5
            url = URL(string: "https://cdn.discordapp.com/embed/avatars/\(defaultIndex).png")
        }
        // print("🖼️ Avatar URL for \(username): \(url?.absoluteString ?? "nil")")
        return url
    }
}

struct User: Codable, Identifiable {
    let id: String
    let location: Location?
    let duser: DiscordUser
    let privacy: PrivacySettings
    let pushToken: String?
    let receiveNearbyNotifications: Bool?
    let allowNearbyNotifications: Bool?
    let nearbyNotificationDistance: Double?
    let allowNearbyNotificationDistance: Double?
}

struct Guild: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String?

    var iconURL: URL? {
        let url: URL?
        if let icon = icon {
            url = URL(string: "https://cdn.discordapp.com/icons/\(id)/\(icon).png")
        } else {
            // Default guild icon - use first two letters of name in a colored circle
            let encodedName = name.prefix(2).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            url = URL(string: "https://ui-avatars.com/api/?name=\(encodedName)&background=random")
        }
        // print("🖼️ Guild icon URL for \(name): \(url?.absoluteString ?? "nil")")
        return url
    }
}

// MARK: - API Manager

@MainActor
class APIManager: ObservableObject {
    static let shared = APIManager()
    private let backendURL = Constants.backendURL
    
    @Published private(set) var currentUser: User?
    @Published private(set) var guilds: [Guild] = []
    @Published private(set) var users: [User] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var refreshInterval: TimeInterval = 30 // Default refresh interval
    
    private var loadTask: Task<Void, Never>?
    private var updateLocationTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var isUpdatingLocation = false
    private var isRefreshingUsers = false
    private var lastUsersFetch: Date?
    private let usersFetchCooldown: TimeInterval = 5 // Minimum seconds between user fetches
    
    private func getAuthToken() -> String? {
        return AuthManager.shared.token
    }
    
    private func getPushToken() -> String? {
        return UserDefaults.standard.string(forKey: "push_token")
    }
    
    // MARK: - Data Loading
    
    func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task {
                // First try to update location if we have permission
                do {
                    try await LocationManager.shared.requestLocationUpdate()
                } catch {
                    print("🌐 APIManager: Location update failed - \(error)")
                }
                
                // Then refresh data
                await self?.loadInitialData()
            }
        }
        print("🌐 APIManager: Started refresh timer with interval \(refreshInterval) seconds")
        
        // Also trigger an immediate update
        Task {
            do {
                try await LocationManager.shared.requestLocationUpdate()
            } catch {
                print("🌐 APIManager: Initial location update failed - \(error)")
            }
            await loadInitialData()
        }
    }
    
    func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("🌐 APIManager: Stopped refresh timer")
    }
    
    func updateRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        if refreshTimer != nil {
            startRefreshTimer()
        }
    }
    
    func loadInitialData() async {
        guard loadTask == nil else {
            // Wait for existing load to complete
            await loadTask?.value
            return
        }
        
        let task = Task {
            do {
                isLoading = true
                error = nil
                
                // Execute all tasks concurrently
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { try await self.fetchCurrentUser() }
                    group.addTask { try await self.fetchGuilds() }
                    group.addTask { try await self.fetchUsers() }
                    try await group.waitForAll()
                }
                
                // Start refresh timer if not already running
                if refreshTimer == nil {
                    startRefreshTimer()
                }
            } catch {
                self.error = error
            }
            isLoading = false
        }
        
        loadTask = task
        await task.value
        loadTask = nil
    }
    
    private func makeRequest<T: Codable>(endpoint: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        guard let token = getAuthToken() else {
            throw NSError(domain: "APIManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No auth token found"])
        }
        
        guard let url = URL(string: "\(backendURL)/\(endpoint)") else {
            throw NSError(domain: "APIManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
            print("🌐 APIManager: Request body for \(endpoint):", String(data: request.httpBody!, encoding: .utf8) ?? "nil")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "APIManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("🌐 APIManager: Response for \(endpoint):", httpResponse.statusCode)
        print("🌐 APIManager: Response data:", String(data: data, encoding: .utf8) ?? "nil")
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            if httpResponse.statusCode == 401 {
                Task { @MainActor in
                    AuthManager.shared.handleInvalidToken()
                }
            }
            
            throw NSError(
                domain: "APIManager",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Request failed: \(errorMessage)"]
            )
        }
        
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(T.self, from: data)
            print("🌐 APIManager: Successfully decoded response for \(endpoint)")
            return result
        } catch {
            print("🌐 APIManager: Decoding error for \(endpoint):", error)
            throw error
        }
    }
    
    // MARK: - User Methods
    
    func fetchCurrentUser() async throws {
        let user: User = try await makeRequest(endpoint: "users/me")
        currentUser = user
    }
    
    func updateCurrentUser(_ user: User) async throws {
        // Always include the current push token in updates
        let updatedUser = User(
            id: user.id,
            location: user.location,
            duser: user.duser,
            privacy: user.privacy,
            pushToken: getPushToken(),
            receiveNearbyNotifications: user.receiveNearbyNotifications,
            allowNearbyNotifications: user.allowNearbyNotifications,
            nearbyNotificationDistance: user.nearbyNotificationDistance,
            allowNearbyNotificationDistance: user.allowNearbyNotificationDistance
        )
        
        let _: [String: Bool] = try await makeRequest(
            endpoint: "users/me",
            method: "POST",
            body: updatedUser
        )
        currentUser = updatedUser
    }
    
    func updateLocation(_ location: Location) async throws {
        guard let currentUser = currentUser else {
            return
        }
        
        let updatedUser = User(
            id: currentUser.id,
            location: location,
            duser: currentUser.duser,
            privacy: currentUser.privacy,
            pushToken: getPushToken(),
            receiveNearbyNotifications: currentUser.receiveNearbyNotifications,
            allowNearbyNotifications: currentUser.allowNearbyNotifications,
            nearbyNotificationDistance: currentUser.nearbyNotificationDistance,
            allowNearbyNotificationDistance: currentUser.allowNearbyNotificationDistance
        )
        
        try await updateCurrentUser(updatedUser)
        
        // Only fetch users if enough time has passed since last fetch
        if let lastFetch = lastUsersFetch {
            let timeSinceLastFetch = Date().timeIntervalSince(lastFetch)
            if timeSinceLastFetch >= usersFetchCooldown {
                try await fetchUsers()
            }
        } else {
            try await fetchUsers()
        }
    }
    
    func fetchUsers() async throws {
        let users: [User] = try await makeRequest(endpoint: "users")
        self.users = users
        lastUsersFetch = Date()
    }
    
    // MARK: - Guild Methods
    
    func fetchGuilds() async throws {
        let guilds: [Guild] = try await makeRequest(endpoint: "guilds")
        self.guilds = guilds
    }
    
    // MARK: - Reset
    
    func reset() {
        loadTask?.cancel()
        updateLocationTask?.cancel()
        stopRefreshTimer()
        loadTask = nil
        updateLocationTask = nil
        currentUser = nil
        guilds = []
        users = []
        isLoading = false
        error = nil
    }
    
    // Add delete user data method
    func deleteUserData() async throws {
        let _: [String: Bool] = try await makeRequest(
            endpoint: "delete-data",
            method: "DELETE"
        )
        reset() // Clear local data after successful deletion
    }
} 