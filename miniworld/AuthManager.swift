import Foundation
import CryptoKit
import UIKit

// Guild model
struct Guild: Codable, Identifiable {
  let id: String
  let name: String
  let icon: String?

  var iconURL: URL? {
    guard let icon = icon else { return nil }
    return URL(string: "https://cdn.discordapp.com/icons/\(id)/\(icon).png")
  }
}

class AuthManager: ObservableObject {
  static let shared = AuthManager()
  private let tokenKey = "auth_token"
  private let clientID = "1232840493696680038"
  private let callbackURL = "miniworld://redirect"
  private let backendURL = "https://d44e-2607-f598-d3a8-0-67-c4fa-8d4a-962d.ngrok-free.app"
  private var currentCodeVerifier: String?

  @Published var isAuthenticated: Bool {
    willSet {
      objectWillChange.send()
    }
  }

  @Published var guilds: [Guild] = []

  init() {
    self.isAuthenticated = UserDefaults.standard.string(forKey: tokenKey) != nil
  }

  // MARK: - OAuth2 PKCE Helper Functions

  private func generateCodeVerifier() -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    return Data(bytes).base64URLEncodedString()
  }

  private func generateCodeChallenge(from verifier: String) -> String {
    let data = Data(verifier.utf8)
    let hash = SHA256.hash(data: data)
    return Data(hash).base64URLEncodedString()
  }

  // MARK: - Auth Flow

  func login() {
    // Generate PKCE code verifier and challenge
    let codeVerifier = generateCodeVerifier()
    self.currentCodeVerifier = codeVerifier
    let codeChallenge = generateCodeChallenge(from: codeVerifier)
    
    // Construct the OAuth2 authorization URL
    var components = URLComponents(string: "https://discord.com/api/oauth2/authorize")!
    components.queryItems = [
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "redirect_uri", value: callbackURL),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: "identify guilds"),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256")
    ]
    
    guard let authURL = components.url else {
      print("Failed to create auth URL")
      return
    }
    
    // Open the URL in the system browser
    DispatchQueue.main.async {
      UIApplication.shared.open(authURL)
    }
  }

  func handleCallback(url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
          let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
          let codeVerifier = self.currentCodeVerifier else {
      print("Invalid callback URL or missing code")
      return
    }
    
    // Exchange the code for a token using our backend
    let tokenURL = "\(backendURL)/token"
    var request = URLRequest(url: URL(string: tokenURL)!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = [
      "code": code,
      "code_verifier": codeVerifier,
      "redirect_uri": callbackURL
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self,
            let data = data,
            let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
        print("Failed to get token: \(error?.localizedDescription ?? "Unknown error")")
        return
      }
      
      // Store the access token
      DispatchQueue.main.async {
        UserDefaults.standard.setValue(tokenResponse.access_token, forKey: self.tokenKey)
        self.isAuthenticated = true
      }
    }.resume()
  }

  // Token response model
  private struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let scope: String
  }

  func logout() {
    UserDefaults.standard.removeObject(forKey: tokenKey)
    isAuthenticated = false
    
    // Optionally revoke the token on the backend
    if let token = UserDefaults.standard.string(forKey: tokenKey) {
      let revokeURL = "\(backendURL)/revoke"
      var request = URLRequest(url: URL(string: revokeURL)!)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      
      URLSession.shared.dataTask(with: request) { _, _, _ in
        print("Token revoked")
      }.resume()
    }
  }

  // MARK: - API Calls

  func fetchGuilds() async throws {
    guard let token = UserDefaults.standard.string(forKey: tokenKey) else {
      throw NSError(
        domain: "AuthManager", code: 401,
        userInfo: [NSLocalizedDescriptionKey: "No auth token found"])
    }

    guard let url = URL(string: "https://discord.com/api/users/@me/guilds") else {
      throw NSError(
        domain: "AuthManager", code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw NSError(
        domain: "AuthManager", code: 0,
        userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }

    guard httpResponse.statusCode == 200 else {
      throw NSError(
        domain: "AuthManager",
        code: httpResponse.statusCode,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Failed to fetch guilds: \(String(data: data, encoding: .utf8) ?? "")"
        ]
      )
    }

    let fetchedGuilds = try JSONDecoder().decode([Guild].self, from: data)
    await MainActor.run {
      self.guilds = fetchedGuilds
    }
  }

  func updatePrivacySettings(enabledGuilds: [String], blockedUsers: [String]) async throws {
    guard let token = UserDefaults.standard.string(forKey: tokenKey) else {
      throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No auth token found"])
    }

    guard let url = URL(string: "\(backendURL)/privacy") else {
      throw NSError(domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = ["enabledGuilds": enabledGuilds, "blockedUsers": blockedUsers]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw NSError(
        domain: "AuthManager",
        code: (response as? HTTPURLResponse)?.statusCode ?? 500,
        userInfo: [NSLocalizedDescriptionKey: "Failed to update privacy settings"]
      )
    }
  }
}

// MARK: - Extensions

extension Data {
  func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
