import Foundation
import OAuthSwift

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
  private let clientSecret = "RJA8G9cEA4ggLAqG-fZ_GsFSTHqwzZmS"
  private let callbackURL = "miniworld://redirect"
  private let backendURL = "https://7558-24-163-63-201.ngrok-free.app/"
  private var oauthswift: OAuth2Swift?
  private var currentCodeVerifier: String?  // Store the code verifier

  @Published var isAuthenticated: Bool {
    willSet {
      objectWillChange.send()
    }
  }

  @Published var guilds: [Guild] = []

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
      codeVerifier: codeVerifier
    ) { result in
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

  func fetchGuilds() async throws {
    guard let token = UserDefaults.standard.string(forKey: tokenKey) else {
      throw NSError(
        domain: "AuthManager", code: 401,
        userInfo: [NSLocalizedDescriptionKey: "No auth token found"])
    }

    guard let url = URL(string: "https://discord.com/api/users/@me/guilds") else {
      throw NSError(
        domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw NSError(
        domain: "AuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
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
}
