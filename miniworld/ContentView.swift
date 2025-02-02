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

#Preview {
    ContentView()
}
