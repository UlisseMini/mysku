import Foundation

// MARK: - Models

struct Location: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
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
    
    private func getAuthToken() -> String? {
        return AuthManager.shared.token
    }
    
    // MARK: - Data Loading
    
    func loadInitialData() {
        guard loadTask == nil else {
            print("📱 APIManager: Initial data load already in progress")
            return
        }
        
        loadTask = Task {
            do {
                isLoading = true
                error = nil
                print("📱 APIManager: Starting initial data load")
                
                // Load everything in parallel
                async let userTask = fetchCurrentUser()
                async let guildsTask = fetchGuilds()
                async let usersTask = fetchUsers()
                
                // Wait for all tasks to complete
                try await (_, _, _) = (userTask, guildsTask, usersTask)
                print("📱 APIManager: Initial data load complete")
            } catch {
                print("📱 APIManager: Initial data load failed - \(error)")
                self.error = error
            }
            isLoading = false
            loadTask = nil
        }
    }
    
    private func makeRequest<T: Codable>(endpoint: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        guard let token = getAuthToken() else {
            print("📱 APIManager: No auth token found")
            throw NSError(domain: "APIManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No auth token found"])
        }
        
        guard let url = URL(string: "\(backendURL)/\(endpoint)") else {
            print("📱 APIManager: Invalid URL for endpoint: \(endpoint)")
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
        
        print("📱 APIManager: Making request to \(endpoint)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("📱 APIManager: Invalid response type")
            throw NSError(domain: "APIManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("📱 APIManager: Request failed (\(httpResponse.statusCode)) - \(errorMessage)")
            
            // Handle invalid token error
            if httpResponse.statusCode == 401 {
                print("📱 APIManager: Invalid token detected, triggering re-authentication")
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
        print("📱 APIManager: Fetching current user")
        let user: User = try await makeRequest(endpoint: "users/me")
        currentUser = user
        print("📱 APIManager: Current user updated - \(user.duser.username)")
    }
    
    func updateCurrentUser(_ user: User) async throws {
        print("📱 APIManager: Updating current user")
        let _: [String: Bool] = try await makeRequest(
            endpoint: "users/me",
            method: "POST",
            body: user
        )
        currentUser = user
        print("📱 APIManager: Current user updated successfully")
    }
    
    func updateLocation(_ location: Location) {
        // Cancel any pending location update
        updateLocationTask?.cancel()
        
        updateLocationTask = Task {
            do {
                guard let currentUser = currentUser else {
                    print("📱 APIManager: Cannot update location - no current user")
                    return
                }
                
                print("📱 APIManager: Updating location for user \(currentUser.duser.username)")
                let updatedUser = User(
                    id: currentUser.id,
                    location: location,
                    duser: currentUser.duser,
                    privacy: currentUser.privacy
                )
                
                try await updateCurrentUser(updatedUser)
                print("📱 APIManager: Location updated successfully")
            } catch {
                print("📱 APIManager: Failed to update location - \(error)")
                self.error = error
            }
            updateLocationTask = nil
        }
    }
    
    func fetchUsers() async throws {
        print("📱 APIManager: Fetching all users")
        let users: [User] = try await makeRequest(endpoint: "users")
        self.users = users
        print("📱 APIManager: Users updated - count: \(users.count)")
    }
    
    // MARK: - Guild Methods
    
    func fetchGuilds() async throws {
        print("📱 APIManager: Fetching guilds")
        let guilds: [Guild] = try await makeRequest(endpoint: "guilds")
        self.guilds = guilds
        print("📱 APIManager: Guilds updated - count: \(guilds.count)")
    }
    
    // MARK: - Reset
    
    func reset() {
        print("📱 APIManager: Resetting all state")
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