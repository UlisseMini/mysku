import Foundation
import CoreLocation

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let locationManager = CLLocationManager()
    private let apiManager = APIManager.shared
    
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 3600 // 1 hour in seconds
    
    override init() {
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
    }
    
    func requestWhenInUseAuthorization() {
        print("📍 LocationManager: Requesting when-in-use authorization...")
        print("📍 LocationManager: Current authorization status: \(locationManager.authorizationStatus.debugDescription)")
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        print("📍 LocationManager: Starting location updates...")
        print("📍 LocationManager: Authorization status: \(locationManager.authorizationStatus.debugDescription)")
        
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
            print("📍 LocationManager: Location updates started")
            
            // Schedule periodic updates
            updateTimer?.invalidate()
            updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
                print("📍 LocationManager: Timer fired - requesting location update")
                self?.locationManager.startUpdatingLocation()
            }
            print("📍 LocationManager: Timer scheduled for \(updateInterval) seconds")
        } else {
            print("📍 LocationManager: ⚠️ Cannot start location updates - not authorized")
        }
    }
    
    func stopUpdatingLocation() {
        print("📍 LocationManager: Stopping location updates...")
        locationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
        print("📍 LocationManager: Location updates stopped and timer invalidated")
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("📍 LocationManager: Received location update with \(locations.count) locations")
        
        guard let location = locations.last else {
            print("📍 LocationManager: ⚠️ No location in update")
            return
        }
        
        print("📍 LocationManager: Latest location - Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude)")
        print("📍 LocationManager: Accuracy: \(location.horizontalAccuracy)m, Timestamp: \(location.timestamp)")
        
        lastLocation = location
        
        // Update location through APIManager
        let newLocation = Location(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy
        )
        
        apiManager.updateLocation(newLocation)
        
        // Stop updates until next scheduled time
        locationManager.stopUpdatingLocation()
        print("📍 LocationManager: Stopped location updates until next scheduled update")
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
            case .locationUnknown:
                print("📍 LocationManager: Location currently unavailable")
            default:
                print("📍 LocationManager: Other CoreLocation error: \(clError.code)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 LocationManager: Authorization status changed to: \(status.debugDescription)")
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse:
            print("📍 LocationManager: User granted when-in-use permission")
            startUpdatingLocation()
        case .denied:
            print("📍 LocationManager: User denied location permission")
            stopUpdatingLocation()
        case .restricted:
            print("📍 LocationManager: Location use is restricted")
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