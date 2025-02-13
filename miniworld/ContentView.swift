//
//  ContentView.swift
//  miniworld
//
//  Created by Ulisse Mini on 1/26/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        if authManager.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .imageScale(.large)
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text("MiniWorld")
                .font(.largeTitle)
                .bold()
            
            Text("Connect with your community")
                .foregroundStyle(.secondary)
            
            LoginButton {
                authManager.login()
            }
        }
    }
}

struct LoginButton: View {
    @State private var showingDemoAlert = false
    @State private var isPressed = false
    
    var onLoginTap: () -> Void
    
    var body: some View {
        Button(action: {}) { // Empty action because we handle it in gesture
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .imageScale(.large)
                Text("Continue with Discord")
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.indigo)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal, 40)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 5.0)
                .onEnded { _ in
                    if isPressed { // Only show alert if still pressed
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
                        onLoginTap()
                    }
                    isPressed = false
                }
        )
        .alert("Continue in demo mode?", isPresented: $showingDemoAlert) {
            Button("Yes") {
                UserDefaults.standard.setValue("demo", forKey: "auth_token")
                AuthManager.shared.isAuthenticated = true
                APIManager.shared.reset()
            }
            Button("No", role: .cancel) {}
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct LocationPermissionView: View {
    @StateObject private var locationManager = LocationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text("Location Access")
                .font(.title)
                .bold()
            
            Text("MiniWorld needs your location to share it with your selected Discord communities while the app is open.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                locationManager.requestWhenInUseAuthorization()
            }) {
                Text("Enable Location Access")
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
        .onChange(of: locationManager.authorizationStatus) { status in
            if status != .notDetermined {
                dismiss()
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
            
            Text("MiniWorld needs location access to function properly. Please enable location access in Settings.")
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

struct MapView: View {
    @StateObject private var apiManager = APIManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @State private var hasInitiallyCentered = false
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
    ))
    @State private var selectedUser: User?
    @State private var showingLocationPermissionSheet = false
    
    var usersWithLocation: [User] {
        apiManager.users.filter { $0.location != nil }
    }
    
    var body: some View {
        Map(position: $position) {
            ForEach(usersWithLocation, id: \.id) { user in
                if let location = user.location {
                    let coordinate = CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )
                    
                    // Add accuracy circle if user is selected
                    if selectedUser?.id == user.id {
                        MapCircle(center: coordinate, radius: location.accuracy)
                            .foregroundStyle(.blue.opacity(0.2))
                            .stroke(.blue.opacity(0.4), lineWidth: 1)
                    }
                    
                    Annotation(coordinate: coordinate) {
                        ZStack(alignment: .center) {
                            // Additional info appears above
                            if selectedUser?.id == user.id {
                                VStack(spacing: 4) {
                                    Text(location.formattedTimeSinceUpdate)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(4)
                                    
                                    Text("\(Int(location.accuracy))m accuracy")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(4)
                                }
                                .offset(y: -50) // Move info above the profile picture
                            }
                            
                            // Profile picture - always centered on location
                            Button(action: { 
                                if selectedUser?.id == user.id {
                                    selectedUser = nil
                                } else {
                                    selectedUser = user
                                }
                            }) {
                                if let avatar = user.duser.avatar {
                                    AsyncImage(url: URL(string: "https://cdn.discordapp.com/avatars/\(user.id)/\(avatar).png")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 40, height: 40)
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    }
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                }
                            }
                            
                            // Username with fixed position below profile picture
                            Text(user.duser.username)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                                .offset(y: 35)
                        }
                    } label: {
                        // Empty label since we're handling the username in the ZStack
                        EmptyView()
                    }
                }
            }
        }
        .mapStyle(.standard)
        .onTapGesture {
            selectedUser = nil
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if apiManager.isLoading {
                    ProgressView()
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                }
                
                if locationManager.authorizationStatus == .notDetermined {
                    Button(action: { showingLocationPermissionSheet = true }) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                            Text("Enable location sharing")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                    .padding()
                } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    HStack {
                        Image(systemName: "location.slash.circle.fill")
                        Text("Location sharing disabled")
                        Spacer()
                        Button("Enable") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .padding()
                }
                
                if let error = apiManager.error {
                    Text(error.localizedDescription)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
            }
        }
        .sheet(isPresented: $showingLocationPermissionSheet) {
            LocationPermissionView()
                .presentationDetents([.medium])
        }
        .task {
            // Load initial data if needed
            if apiManager.currentUser == nil {
                await apiManager.loadInitialData()
            }
        }
        .refreshable {
            await apiManager.loadInitialData()
        }
        .onChange(of: locationManager.lastLocation) { newLocation in
            if let location = newLocation, !hasInitiallyCentered {
                position = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
                ))
                hasInitiallyCentered = true
            }
        }
    }
}

#Preview {
    ContentView()
}
