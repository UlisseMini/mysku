import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .imageScale(.large)
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text(Constants.appName.capitalized)
                .font(.largeTitle)
                .bold()
            
            Text("Connect with your community")
                .foregroundStyle(.secondary)
            
            LoginButton {
                authManager.login()
            }
        }
        .onAppear {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.view.window?.rootViewController = window.rootViewController
            }
        }
    }
}

struct LoginButton: View {
    @State private var showingDemoAlert = false
    @State private var isPressed = false
    
    var onLoginTap: () -> Void
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .imageScale(.large)
                Text("Continue with Discord")
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: min(UIScreen.main.bounds.width - 80, 360))
            .background(Color.indigo)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal, 40)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 3.0)
                .onEnded { _ in
                    if isPressed {
                        showingDemoAlert = true
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    if isPressed && !showingDemoAlert {
                        if ProcessInfo.processInfo.arguments.contains("-AutoDemo") {
                            continueInDemoMode()
                        } else {
                            onLoginTap()
                        }
                    }
                    isPressed = false
                }
        )
        .alert("Continue in demo mode?", isPresented: $showingDemoAlert) {
            Button("Yes") {
                continueInDemoMode()
            }
            Button("No", role: .cancel) {}
        }
    }
} 

@MainActor
func continueInDemoMode() {
    UserDefaults.standard.setValue("demo", forKey: "auth_token")
    AuthManager.shared.isAuthenticated = true
    APIManager.shared.reset()
}