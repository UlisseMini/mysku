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
    @StateObject private var locationManager = LocationManager.shared
    
    var body: some View {
        if authManager.isAuthenticated {
            MainTabView()
                .onAppear {
                    locationManager.requestWhenInUseAuthorization()
                }
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
            
            Button(action: { authManager.login() }) {
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

struct MapView: View {
    @StateObject private var apiManager = APIManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))
    
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
                    
                    Annotation(coordinate: coordinate) {
                        // Discord avatar
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
                    } label: {
                        Text(user.duser.username)
                    }
                }
            }
        }
        .mapStyle(.standard)
        .overlay(alignment: .center) {
            if apiManager.isLoading {
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
        }
        .overlay(alignment: .top) {
            if let error = apiManager.error {
                Text(error.localizedDescription)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.top)
            }
        }
        .task {
            // Load initial data if needed
            if apiManager.currentUser == nil {
                apiManager.loadInitialData()
            }
        }
        .refreshable {
            apiManager.loadInitialData()
        }
    }
}

#Preview {
    ContentView()
}
