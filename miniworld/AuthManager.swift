import Foundation
import OAuthSwift

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    private let tokenKey = "auth_token"
    private let clientID = "1232840493696680038"
    private let clientSecret = "RJA8G9cEA4ggLAqG-fZ_GsFSTHqwzZmS"
    private let callbackURL = "miniworld://redirect"
    private let backendURL = "https://a15a-24-163-63-201.ngrok-free.app"
    private var oauthswift: OAuth2Swift?
    private var currentCodeVerifier: String?  // Store the code verifier
    
    @Published var isAuthenticated: Bool {
        willSet {
            objectWillChange.send()
        }
    }
    
    init() {
        self.isAuthenticated = UserDefaults.standard.string(forKey: tokenKey) != nil
    }
    
    func login() {
        oauthswift = OAuth2Swift(
            consumerKey: clientID,
            consumerSecret: clientSecret,
            authorizeUrl: "https://discord.com/api/oauth2/authorize",
            accessTokenUrl: "https://discord.com/api/oauth2/token",
            responseType: "code"
        )
        
        oauthswift?.accessTokenBasicAuthentification = true
        
        guard let codeVerifier = generateCodeVerifier() else {
            print("Failed to generate code verifier")
            return
        }
        
        self.currentCodeVerifier = codeVerifier  // Store it for later use
        
        guard let codeChallenge = generateCodeChallenge(codeVerifier: codeVerifier) else {
            print("Failed to generate code challenge")
            return
        }
        
        print("Starting authorization...")
        let _ = oauthswift?.authorize(
            withCallbackURL: callbackURL,
            scope: "identify guilds",
            state: "state",
            codeChallenge: codeChallenge,
            codeChallengeMethod: "S256",
            codeVerifier: codeVerifier) { result in
                switch result {
                case .success(let (credential, _, _)):
                    // Send the code to our backend
                    print("Received code: \(credential.oauthToken)")
                    self.handleSuccessfulLogin(credential: credential)
                case .failure(let error):
                    print("OAuth error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isAuthenticated = false
                    }
                }
            }
    }
    
    private func handleSuccessfulLogin(credential: OAuthSwiftCredential) {
        print("Starting handleSuccessfulLogin...")
        print("OAuth Token: \(credential.oauthToken)")
        
        Task {
            do {
                guard let url = URL(string: "https://discord.com/api/users/@me") else {
                    print("Failed to construct Discord API URL")
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(credential.oauthToken)", forHTTPHeaderField: "Authorization")
                
                print("Making request to Discord API...")
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("Failed to get user data. Status code: \(httpResponse.statusCode)")
                    print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode response")")
                    return
                }
                
                let userData = try JSONDecoder().decode(DiscordUser.self, from: data)
                print("Successfully got user data for: \(userData.username)")
                
                // Store the access token in UserDefaults
                await MainActor.run {
                    UserDefaults.standard.setValue(credential.oauthToken, forKey: self.tokenKey)
                    self.isAuthenticated = true
                    print("Updated UserDefaults and set isAuthenticated to true")
                }
            } catch {
                print("Error during login: \(error)")
                print("Error details: \(error.localizedDescription)")
            }
        }
    }
    
    // Discord User model
    struct DiscordUser: Codable {
        let id: String
        let username: String
        let discriminator: String
        let avatar: String?
        let email: String?
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        isAuthenticated = false
        
        // Revoke token if needed
        if let token = oauthswift?.client.credential.oauthToken {
            oauthswift?.client.post(
                "https://discord.com/api/oauth2/token/revoke",
                parameters: ["token": token]
            ) { _ in
                print("Token revoked")
            }
        }
    }
} 