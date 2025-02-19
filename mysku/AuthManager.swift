import Foundation
import CryptoKit
import UIKit
import AuthenticationServices

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    private let tokenKey = Constants.tokenKey
    private let clientID = Constants.clientID
    private let callbackURL = Constants.callbackURL
    private let backendURL = Constants.backendURL
    private var currentCodeVerifier: String?
    private var pendingCode: String?
    private var retryCount = 0
    private let maxRetries = 3
    
    private var isHandlingCallback = false {
        didSet {
            print("AuthManager: isHandlingCallback changed to \(isHandlingCallback)")
        }
    }

    @Published var isAuthenticated: Bool {
        willSet {
            print("AuthManager: isAuthenticated changing from \(isAuthenticated) to \(newValue)")
            objectWillChange.send()
        }
    }
    
    var token: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    private var authSession: ASWebAuthenticationSession?

    init() {
        let hasToken = UserDefaults.standard.string(forKey: tokenKey) != nil
        print("AuthManager: Initializing with token present: \(hasToken)")
        self.isAuthenticated = hasToken
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
        print("AuthManager: Starting login flow")
        
        // Reset all state
        self.isHandlingCallback = false
        self.pendingCode = nil
        self.retryCount = 0
        
        // Generate PKCE code verifier and challenge
        let codeVerifier = generateCodeVerifier()
        print("AuthManager: Generated new code verifier")
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
            print("AuthManager: Failed to create auth URL")
            return
        }
        
        print("AuthManager: Creating auth session")
        authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "mysku") { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            if let error = error {
                print("AuthManager: Auth session failed: \(error)")
                self.resetState()
                return
            }
            
            guard let callbackURL = callbackURL else {
                print("AuthManager: No callback URL received")
                self.resetState()
                return
            }
            
            self.handleCallback(url: callbackURL)
        }
        
        authSession?.presentationContextProvider = UIApplication.shared.keyWindow?.rootViewController as? ASWebAuthenticationPresentationContextProviding
        
        print("AuthManager: Starting auth session")
        authSession?.start()
    }

    private func exchangeCodeForToken() {
        guard let code = pendingCode, let codeVerifier = currentCodeVerifier else {
            print("AuthManager: Missing code or verifier for token exchange")
            self.isHandlingCallback = false
            return
        }
        
        print("AuthManager: Exchanging code for token (attempt \(retryCount + 1)/\(maxRetries))")
        
        Task {
            do {
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
                
                let (data, _) = try await URLSession.shared.data(for: request)
                
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("AuthManager: Received token response: \(responseStr)")
                }
                
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                print("AuthManager: Successfully received token")
                
                UserDefaults.standard.setValue(tokenResponse.access_token, forKey: self.tokenKey)
                self.isAuthenticated = true
                print("AuthManager: Completed login flow, isAuthenticated = true")
                self.resetState()
                APIManager.shared.reset() // Reset API state on new login
                
            } catch {
                print("AuthManager: Token exchange failed with error: \(error)")
                
                if (error as NSError).domain == NSURLErrorDomain,
                   self.retryCount < self.maxRetries {
                    self.retryCount += 1
                    print("AuthManager: Retrying token exchange after delay...")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    self.exchangeCodeForToken()
                    return
                }
                
                self.resetState()
            }
        }
    }
    
    private func resetState() {
        print("AuthManager: Resetting state")
        self.isHandlingCallback = false
        self.currentCodeVerifier = nil
        self.pendingCode = nil
        self.retryCount = 0
    }

    func handleCallback(url: URL) {
        print("AuthManager: Received callback URL: \(url)")
        
        guard !isHandlingCallback else {
            print("AuthManager: Already handling a callback, ignoring")
            return
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("AuthManager: Invalid callback URL or missing code")
            return
        }
        
        guard currentCodeVerifier != nil else {
            print("AuthManager: Missing code verifier")
            return
        }
        
        isHandlingCallback = true
        pendingCode = code
        exchangeCodeForToken()
    }

    func logout() {
        // Revoke the token on the backend
        Task {
            if let token = token {
                let revokeURL = "\(backendURL)/revoke"
                var request = URLRequest(url: URL(string: revokeURL)!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                do {
                    let (_, _) = try await URLSession.shared.data(for: request)
                    print("Token revoked")
                } catch {
                    print("Failed to revoke token: \(error)")
                }
            }

            // Remove the token from the user defaults
            UserDefaults.standard.removeObject(forKey: tokenKey)
            isAuthenticated = false
            APIManager.shared.reset() // Reset API state on logout
        }
    }

    func handleInvalidToken() {
        print("AuthManager: Handling invalid token")
        // Remove the token from user defaults
        UserDefaults.standard.removeObject(forKey: tokenKey)
        isAuthenticated = false
        APIManager.shared.reset() // Reset API state
    }

    // Token response model
    private struct TokenResponse: Codable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let scope: String
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

extension UIViewController: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}
