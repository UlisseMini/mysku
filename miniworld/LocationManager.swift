import Foundation
import CoreLocation

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let locationManager = CLLocationManager()
    private let apiManager = APIManager.shared
    
    private let updateInterval: TimeInterval = 30 // Update every 30 seconds
    private let minimumMovementThreshold = 100.0 // Minimum movement in meters to trigger an update
    private var lastReportedLocation: CLLocation?
    
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    private var updateTimer: Timer?
    private var isUpdating = false
    
    override init() {
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
            requestLocationUpdate()
            
            // Schedule periodic updates for our location
            updateTimer?.invalidate()
            updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
                print("📍 LocationManager: Timer fired - requesting location update")
                self?.requestLocationUpdate()
            }
            print("📍 LocationManager: Location update timer scheduled for \(updateInterval) seconds")
        }
    }
    
    private func requestLocationUpdate() {
        // Early return if we don't have permission or update in progress
        guard locationManager.authorizationStatus == .authorizedWhenInUse else {
            print("📍 LocationManager: Cannot request location update - not authorized")
            return
        }
        
        guard !isUpdating else {
            print("📍 LocationManager: Update already in progress, skipping new update request")
            return
        }
        
        isUpdating = true
        locationManager.startUpdatingLocation()
        print("📍 LocationManager: Location update requested")
    }
    
    func stopUpdatingLocation() {
        print("📍 LocationManager: Stopping location updates...")
        locationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
        isUpdating = false
        lastLocation = nil // Clear the last location when stopping updates
        print("📍 LocationManager: Location updates stopped and timer invalidated")
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Early return if we lost permission while updating
        guard locationManager.authorizationStatus == .authorizedWhenInUse else {
            stopUpdatingLocation()
            return
        }
        
        guard let location = locations.last else {
            isUpdating = false
            return
        }
        
        // Only log significant changes in location
        if let lastLocation = lastReportedLocation {
            let distance = location.distance(from: lastLocation)
            if distance < minimumMovementThreshold {
                locationManager.stopUpdatingLocation()
                isUpdating = false
                return
            }
            print("📍 LocationManager: Significant movement detected: \(Int(distance))m")
        }
        
        print("📍 LocationManager: Location update - Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude)")
        print("📍 LocationManager: Accuracy: \(Int(location.horizontalAccuracy))m")
        
        lastLocation = location
        lastReportedLocation = location
        
        // Update location through APIManager and refresh users list
        Task {
            do {
                let newLocation = Location(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    accuracy: location.horizontalAccuracy,
                    lastUpdated: Date().timeIntervalSince1970 * 1000
                )
                
                try await apiManager.updateLocation(newLocation)
            } catch {
                print("📍 LocationManager: Failed to update location - \(error)")
            }
            
            locationManager.stopUpdatingLocation()
            isUpdating = false
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
        
        isUpdating = false
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