import Foundation
import CoreLocation

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let locationManager = CLLocationManager()
    private let apiManager = APIManager.shared
    
    private let updateInterval: TimeInterval = 30 // Update every 30 seconds
    private let minimumMovementThreshold = 100.0 // Minimum movement in meters to trigger an update
    
    // Privacy settings
    private var privacyAngle: Double
    
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    private var lastReportedLocation: CLLocation?
    private var lastUpdatePrivacyRadius: Double?  // Track privacy radius of last update
    
    override init() {
        // Initialize or load privacy angle
        if let angle = UserDefaults.standard.object(forKey: "privacyAngle") as? Double {
            privacyAngle = angle
        } else {
            privacyAngle = Double.random(in: 0...(2 * .pi))
            UserDefaults.standard.set(privacyAngle, forKey: "privacyAngle")
        }
        
        // Initialize privacy radius if not set
        if UserDefaults.standard.object(forKey: "privacyRadius") == nil {
            UserDefaults.standard.set(2000.0, forKey: "privacyRadius") // Default 2km
        }
        
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        print("📍 LocationManager: Initializing...")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        
        // Print initial state
        print("📍 LocationManager: Initial authorization status: \(locationManager.authorizationStatus.debugDescription)")
        if let location = locationManager.location {
            print("📍 LocationManager: Initial location available: \(location.coordinate)")
        } else {
            print("📍 LocationManager: No initial location available")
        }
        
        // If we already have permission, start updates
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            startUpdatingLocation()
        }
    }
    
    private func applyPrivacyOffset(to location: CLLocation) -> CLLocation {
        let privacyRadius = UserDefaults.standard.double(forKey: "privacyRadius")
        
        // If privacy radius is 0, return original location
        if privacyRadius == 0 {
            return location
        }
        
        // Convert polar coordinates to cartesian
        let offsetLatitude = privacyRadius * cos(privacyAngle) / 111000 // Approx meters per degree latitude
        let offsetLongitude = privacyRadius * sin(privacyAngle) / 111000
        
        let newLatitude = location.coordinate.latitude + offsetLatitude
        let newLongitude = location.coordinate.longitude + offsetLongitude
        
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude),
            altitude: location.altitude,
            horizontalAccuracy: max(privacyRadius, location.horizontalAccuracy),
            verticalAccuracy: location.verticalAccuracy,
            timestamp: location.timestamp
        )
    }
    
    func requestWhenInUseAuthorization() {
        print("📍 LocationManager: Requesting when-in-use authorization...")
        print("📍 LocationManager: Current authorization status: \(locationManager.authorizationStatus.debugDescription)")
        
        // Only request if we're in notDetermined state
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse {
            // If we already have permission, start updates
            startUpdatingLocation()
        }
    }
    
    func startUpdatingLocation() {
        print("📍 LocationManager: Starting location updates...")
        print("📍 LocationManager: Authorization status: \(locationManager.authorizationStatus.debugDescription)")
        
        // Early return if we don't have permission
        guard locationManager.authorizationStatus == .authorizedWhenInUse else {
            print("📍 LocationManager: Cannot start location updates - not authorized")
            return
        }
        
        // First ensure initial data is loaded
        Task {
            if apiManager.currentUser == nil {
                print("📍 LocationManager: Waiting for initial data load...")
                await apiManager.loadInitialData()
            }
            
            // Now start location updates
            do {
                try await requestLocationUpdate()
            } catch {
                print("📍 LocationManager: Initial location update failed - \(error)")
            }
        }
    }
    
    // Single async method for requesting location updates
    func requestLocationUpdate() async throws {
        // Early return if we don't have permission
        guard locationManager.authorizationStatus == .authorizedWhenInUse else {
            print("📍 LocationManager: Cannot request location update - not authorized")
            throw LocationError.notAuthorized
        }
        
        // Get current location
        guard let location = locationManager.location else {
            print("📍 LocationManager: No location available")
            throw LocationError.updateFailed
        }
        
        // Apply privacy offset
        let privatizedLocation = applyPrivacyOffset(to: location)
        
        print("📍 LocationManager: Location update - Lat: \(privatizedLocation.coordinate.latitude), Lon: \(privatizedLocation.coordinate.longitude)")
        print("📍 LocationManager: Accuracy: \(Int(privatizedLocation.horizontalAccuracy))m")
        
        // Update our stored values
        lastLocation = privatizedLocation
        lastReportedLocation = location
        lastUpdatePrivacyRadius = UserDefaults.standard.double(forKey: "privacyRadius")
        
        // Update location through APIManager
        let newLocation = Location(
            latitude: privatizedLocation.coordinate.latitude,
            longitude: privatizedLocation.coordinate.longitude,
            accuracy: privatizedLocation.horizontalAccuracy,
            lastUpdated: Date().timeIntervalSince1970 * 1000
        )
        
        try await apiManager.updateLocation(newLocation)
    }
    
    enum LocationError: Error {
        case notAuthorized
        case updateFailed
    }
    
    func stopUpdatingLocation() {
        print("📍 LocationManager: Stopping location updates...")
        locationManager.stopUpdatingLocation()
        lastLocation = nil // Clear the last location when stopping updates
        print("📍 LocationManager: Location updates stopped")
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Early return if we lost permission while updating
        guard locationManager.authorizationStatus == .authorizedWhenInUse else {
            stopUpdatingLocation()
            return
        }
        
        guard let location = locations.last else {
            return
        }
        
        // Only update if we've moved significantly
        if let lastLocation = lastReportedLocation {
            let distance = location.distance(from: lastLocation)
            if distance < minimumMovementThreshold {
                return
            }
            print("📍 LocationManager: Significant movement detected: \(Int(distance))m")
        }
        
        // This is just for background updates, not our manual updates
        Task {
            try? await requestLocationUpdate()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 LocationManager: ❌ Location update failed")
        print("📍 LocationManager: Error type: \(type(of: error))")
        print("📍 LocationManager: Error description: \(error.localizedDescription)")
        
        if let clError = error as? CLError {
            print("📍 LocationManager: CLError code: \(clError.code.rawValue)")
            switch clError.code {
            case .denied:
                print("📍 LocationManager: Location services denied by user")
                stopUpdatingLocation()
            case .locationUnknown:
                print("📍 LocationManager: Location currently unavailable")
            case .network:
                print("📍 LocationManager: Network error occurred")
            case .deferredAccuracyTooLow:
                print("📍 LocationManager: Location request was cancelled - this is expected when stopping updates")
            default:
                print("📍 LocationManager: Other CoreLocation error: \(clError.code)")
                print("📍 LocationManager: Detailed error: \(error)")
            }
        } else {
            print("📍 LocationManager: Non-CLError occurred: \(error)")
            print("📍 LocationManager: Detailed error: \(error)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 LocationManager: Authorization status changed to: \(status.debugDescription)")
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse:
            print("📍 LocationManager: User granted when-in-use permission")
            startUpdatingLocation()
        case .denied, .restricted:
            print("📍 LocationManager: Location use is denied or restricted")
            stopUpdatingLocation()
        case .notDetermined:
            print("📍 LocationManager: Permission not determined yet")
        default:
            print("📍 LocationManager: Other authorization status: \(status)")
        }
    }
}

// MARK: - Debug Helpers

extension CLAuthorizationStatus {
    var debugDescription: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }
} 