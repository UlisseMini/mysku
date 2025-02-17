import SwiftUI
import MapKit
import CoreLocation

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
    @Binding var selectedTab: Int
    
    var usersWithLocation: [User] {
        apiManager.users.filter { $0.location != nil }
    }
    
    var body: some View {
        MapContent(
            position: $position,
            selectedUser: $selectedUser,
            users: usersWithLocation
        )
        .overlay(alignment: .top) {
            MapOverlay(
                apiManager: apiManager,
                locationManager: locationManager,
                showingLocationPermissionSheet: $showingLocationPermissionSheet,
                selectedTab: $selectedTab
            )
        }
        .sheet(isPresented: $showingLocationPermissionSheet) {
            LocationPermissionView()
                .presentationDetents([.medium])
        }
        .task {
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

private struct MapContent: View {
    @Binding var position: MapCameraPosition
    @Binding var selectedUser: User?
    let users: [User]
    
    var body: some View {
        Map(position: $position) {
            ForEach(users, id: \.id) { user in
                if let location = user.location {
                    let coordinate = CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )
                    
                    if selectedUser?.id == user.id {
                        MapCircle(center: coordinate, radius: location.accuracy)
                            .foregroundStyle(.blue.opacity(0.2))
                            .stroke(.blue.opacity(0.4), lineWidth: 1)
                    }
                    
                    Annotation(coordinate: coordinate) {
                        ZStack(alignment: .center) {
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
                                .offset(y: -50)
                            }
                            
                            Button(action: { 
                                if selectedUser?.id == user.id {
                                    selectedUser = nil
                                } else {
                                    selectedUser = user
                                }
                            }) {
                                AsyncImage(url: user.duser.avatarURL) { image in
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
                            }
                            
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
                        EmptyView()
                    }
                }
            }
        }
        .mapStyle(.standard)
        .onTapGesture {
            selectedUser = nil
        }
    }
}

private struct MapOverlay: View {
    @ObservedObject var apiManager: APIManager
    @ObservedObject var locationManager: LocationManager
    @Binding var showingLocationPermissionSheet: Bool
    @Binding var selectedTab: Int
    
    var body: some View {
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
                .padding(.horizontal)
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
                .padding(.horizontal)
            }
            
            if apiManager.currentUser?.privacy.enabledGuilds.isEmpty == true {
                Button(action: { selectedTab = 1 }) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.white)
                        Text("No Discord servers enabled")
                            .foregroundColor(.white)
                        Spacer()
                        Text("Settings")
                            .foregroundColor(Color(.systemGray3))
                    }
                }
                .padding()
                .background(Color.black.opacity(0.75))
                .cornerRadius(10)
                .shadow(radius: 2)
                .padding(.horizontal)
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
} 