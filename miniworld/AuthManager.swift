import Foundation

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    private let tokenKey = "auth_token"
    
    @Published var isAuthenticated: Bool {
        willSet {
            objectWillChange.send()
        }
    }
    
    init() {
        self.isAuthenticated = UserDefaults.standard.string(forKey: tokenKey) != nil
    }
    
    func login() {
        UserDefaults.standard.setValue("dummy_token", forKey: tokenKey)
        isAuthenticated = true
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        isAuthenticated = false
    }
} 