import SwiftUI

struct LocationPermissionView: View {
    @StateObject private var locationManager = LocationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            if locationManager.showingBackgroundPrompt {
                backgroundPromptContent
            } else {
                initialPromptContent
            }
        }
        .onChange(of: locationManager.authorizationStatus) { status in
            if status == .authorizedWhenInUse {
                locationManager.showingBackgroundPrompt = true
            } else if status == .authorizedAlways || status == .denied || status == .restricted {
                dismiss()
            }
        }
    }
    
    private var initialPromptContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text("Location Access")
                .font(.title)
                .bold()
            
            Text("\(Constants.appName.capitalized) uses your location to show you on the map with your selected Discord communities while the app is open.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                locationManager.requestWhenInUseAuthorization()
            }) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top)
        }
    }
    
    private var backgroundPromptContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text("Background Location")
                .font(.title)
                .bold()
            
            Text("Would you like to share your location even when the app is in the background? This helps keep your location up to date for your Discord communities.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                locationManager.requestAlwaysAuthorization()
            }) {
                Text("Enable Background Location")
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top)
            
            Button(action: {
                dismiss()
            }) {
                Text("Not Now")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Location Access Required")
                .font(.title)
                .bold()
            
            Text("\(Constants.appName.capitalized) needs location access to function properly. Please enable location access in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }) {
                Text("Open Settings")
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top)
        }
    }
}

// Add a new view for the refresh button
struct LocationRefreshButton: View {
    @StateObject private var locationManager = LocationManager.shared
    @State private var isRefreshing = false
    
    var body: some View {
        Button {
            Task {
                isRefreshing = true
                do {
                    try await locationManager.requestLocationUpdate()
                } catch {
                    print("Failed to update location: \(error)")
                }
                isRefreshing = false
            }
        } label: {
            Image(systemName: "location.circle")
                .font(.system(size: 22))
                .symbolEffect(.bounce, value: isRefreshing)
        }
    }
} 