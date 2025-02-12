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

struct User: Codable {
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

class APIManager: ObservableObject {
    static let shared = APIManager()
    private let backendURL = "https://d44e-2607-f598-d3a8-0-67-c4fa-8d4a-962d.ngrok-free.app"
    
    @Published private(set) var currentUser: User?
    @Published private(set) var guilds: [Guild] = []
    @Published private(set) var users: [User] = []
    
    private func getAuthToken() -> String? {
        return AuthManager.shared.token
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
        await MainActor.run {
            self.currentUser = user
        }
    }
    
    func updateCurrentUser(_ user: User) async throws {
        let _: [String: Bool] = try await makeRequest(
            endpoint: "users/me",
            method: "POST",
            body: user
        )
        await MainActor.run {
            self.currentUser = user
        }
    }
    
    func fetchUsers() async throws {
        let users: [User] = try await makeRequest(endpoint: "users")
        await MainActor.run {
            self.users = users
        }
    }
    
    // MARK: - Guild Methods
    
    func fetchGuilds() async throws {
        let guilds: [Guild] = try await makeRequest(endpoint: "guilds")
        await MainActor.run {
            self.guilds = guilds
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        currentUser = nil
        guilds = []
        users = []
    }
} 