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
    @State private var isAuthenticated = false
    
    var body: some View {
        if isAuthenticated {
            MainTabView()
        } else {
            LoginView(isAuthenticated: $isAuthenticated)
        }
    }
}

struct LoginView: View {
    @Binding var isAuthenticated: Bool
    
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
            
            Button(action: { isAuthenticated = true }) {
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
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))
    
    let people = Person.sampleData
    
    var body: some View {
        Map(position: $position) {
            ForEach(people) { person in
                Annotation(coordinate: person.coordinate) {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.blue)
                        .background(.white)
                        .clipShape(Circle())
                } label: {
                    Text(person.name)
                }
            }
        }
        .mapStyle(.standard)
    }
}

struct SettingsView: View {
    @State private var privacyRadius = 100.0
    @State private var locationUpdatesEnabled = true
    @State private var selectedServers: Set<String> = ["Server 1", "Server 2"]
    let availableServers = ["Server 1", "Server 2", "Server 3", "Server 4"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Privacy") {
                    Toggle("Location Updates", isOn: $locationUpdatesEnabled)
                    
                    VStack(alignment: .leading) {
                        Text("Privacy Radius: \(Int(privacyRadius))m")
                        Slider(value: $privacyRadius, in: 50...1000)
                    }
                }
                
                Section("Visible to servers") {
                    ForEach(availableServers, id: \.self) { server in
                        Toggle(server, isOn: Binding(
                            get: { selectedServers.contains(server) },
                            set: { isSelected in
                                if isSelected {
                                    selectedServers.insert(server)
                                } else {
                                    selectedServers.remove(server)
                                }
                            }
                        ))
                    }
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        // TODO: Implement sign out
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
}
