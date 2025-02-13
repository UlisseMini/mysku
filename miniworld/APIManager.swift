import Foundation

// MARK: - Models

struct Location: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
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
    let discriminator: String
    let avatar: String?
}

struct User: Codable, Identifiable {
    let id: String
    let location: Location?
    let duser: DiscordUser
    let privacy: PrivacySettings
}

struct Guild: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String?

    var iconURL: URL? {
        guard let icon = icon else { return nil }
        return URL(string: "https://cdn.discordapp.com/icons/\(id)/\(icon).png")
    }
}

// MARK: - API Manager

@MainActor
class APIManager: ObservableObject {
    static let shared = APIManager()
    private let backendURL = "https://d44e-2607-f598-d3a8-0-67-c4fa-8d4a-962d.ngrok-free.app"
    
    @Published private(set) var currentUser: User?
    @Published private(set) var guilds: [Guild] = []
    @Published private(set) var users: [User] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private var loadTask: Task<Void, Never>?
    private var updateLocationTask: Task<Void, Never>?
    private var isUpdatingLocation = false
    private var isRefreshingUsers = false
    private var lastUsersFetch: Date?
    private let usersFetchCooldown: TimeInterval = 5 // Minimum seconds between user fetches
    
    private func getAuthToken() -> String? {
        return AuthManager.shared.token
    }
    
    // MARK: - Data Loading
    
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
                
                // Load everything in parallel
                async let userTask = fetchCurrentUser()
                async let guildsTask = fetchGuilds()
                async let usersTask = fetchUsers()
                
                try await (_, _, _) = (userTask, guildsTask, usersTask)
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
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "APIManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            if httpResponse.statusCode == 401 {
                Task {
                    await AuthManager.shared.handleInvalidToken()
                }
            }
            
            throw NSError(
                domain: "APIManager",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Request failed: \(errorMessage)"]
            )
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - User Methods
    
    func fetchCurrentUser() async throws {
        let user: User = try await makeRequest(endpoint: "users/me")
        currentUser = user
    }
    
    func updateCurrentUser(_ user: User) async throws {
        let _: [String: Bool] = try await makeRequest(
            endpoint: "users/me",
            method: "POST",
            body: user
        )
        currentUser = user
    }
    
    func updateLocation(_ location: Location) async throws {
        guard let currentUser = currentUser else {
            return
        }
        
        let updatedUser = User(
            id: currentUser.id,
            location: location,
            duser: currentUser.duser,
            privacy: currentUser.privacy
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
        loadTask = nil
        updateLocationTask = nil
        currentUser = nil
        guilds = []
        users = []
        isLoading = false
        error = nil
    }
} 