import Foundation
import CoreLocation
import UIKit

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let locationManager = CLLocationManager()
    private let apiManager = APIManager.shared
    
    private var lastReportedLocation: CLLocation?
    
    override init() {
        // Set default update interval if not already set
        if UserDefaults.standard.double(forKey: "locationUpdateInterval") == 0 {
            UserDefaults.standard.set(60.0, forKey: "locationUpdateInterval") // Default to 1 minute
        }
        
        // Set default minimum movement threshold if not already set
        if UserDefaults.standard.double(forKey: "minimumMovementThreshold") == 0 {
            UserDefaults.standard.set(1000.0, forKey: "minimumMovementThreshold") // Default to 1km
        }
        
        // Set default desired accuracy if not already set
        if UserDefaults.standard.double(forKey: "desiredAccuracy") == 0 {
            UserDefaults.standard.set(0.0, forKey: "desiredAccuracy") // Default to full accuracy
        }
        
        // Enable background updates by default if not already set
        if !UserDefaults.standard.bool(forKey: "backgroundUpdatesEnabled") {
            UserDefaults.standard.set(true, forKey: "backgroundUpdatesEnabled")
        }
        
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        print("📍 LocationManager: Initializing...")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.pausesLocationUpdatesAutomatically = true
        
        // Configure background updates based on stored settings
        configureBackgroundUpdates()
        
        // Add notification observer for app becoming active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Print initial state
        print("📍 LocationManager: Initial authorization status: \(locationManager.authorizationStatus.debugDescription)")
        if let location = locationManager.location {
            print("📍 LocationManager: Initial location available: \(location.coordinate)")
        } else {
            print("📍 LocationManager: No initial location available")
        }
        
        // If we already have permission, start updates
        if locationManager.authorizationStatus == .authorizedWhenInUse || 
           locationManager.authorizationStatus == .authorizedAlways {
            startUpdatingLocation()
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        print("📍 LocationManager: App became active, requesting location update")
        // Request a location update when app becomes active
        Task {
            do {
                try await requestLocationUpdate()
            } catch {
                print("📍 LocationManager: Location update failed when app became active - \(error)")
            }
        }
    }
    
    private func configureBackgroundUpdates() {
        // Only enable background updates if we have permission and it's enabled in settings
        let canUseBackground = locationManager.authorizationStatus == .authorizedAlways && backgroundUpdatesEnabled
        
        locationManager.allowsBackgroundLocationUpdates = canUseBackground
        
        // Fix for default update interval - ensure we have a valid interval
        if updateInterval <= 0 {
            updateInterval = 60.0 // Set to default 1 minute if invalid
            print("📍 LocationManager: Fixed invalid update interval to 60s")
        }
        
        // Configure the update distance filter based on the update interval
        // More frequent updates = smaller distance filter
        if canUseBackground {
            // Set distance filter based on update interval
            // Shorter intervals = smaller distance filter
            if updateInterval <= 30 {
                locationManager.distanceFilter = 50 // Update if moved 50m
            } else if updateInterval <= 60 {
                locationManager.distanceFilter = 100 // Update if moved 100m
            } else {
                locationManager.distanceFilter = 200 // Update if moved 200m
            }
            
            print("📍 LocationManager: Background updates enabled with interval \(updateInterval)s and distance filter \(locationManager.distanceFilter)m")
        } else {
            // When not in background mode, use a standard distance filter
            locationManager.distanceFilter = kCLDistanceFilterNone
            print("📍 LocationManager: Background updates disabled")
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
    
    func requestAlwaysAuthorization() {
        print("📍 LocationManager: Requesting always authorization...")
        // Request authorization first, we'll enable background updates after permission is granted
        locationManager.requestAlwaysAuthorization()
    }
    
    func startUpdatingLocation() {
        print("📍 LocationManager: Starting location updates...")
        print("📍 LocationManager: Authorization status: \(locationManager.authorizationStatus.debugDescription)")
        
        // Early return if we don't have permission
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            print("📍 LocationManager: Cannot start location updates - not authorized")
            return
        }
        
        // Configure background updates based on current settings
        configureBackgroundUpdates()
        
        // First ensure initial data is loaded
        Task {
            if apiManager.currentUser == nil {
                print("📍 LocationManager: Waiting for initial data load...")
                await apiManager.loadInitialData()
            }
            
            // Start location updates
            locationManager.startUpdatingLocation()
            
            // Now request an immediate location update
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
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            print("📍 LocationManager: Cannot request location update - not authorized")
            throw LocationError.notAuthorized
        }
        
        // Get current location
        guard let location = locationManager.location else {
            print("📍 LocationManager: No location available")
            throw LocationError.updateFailed
        }
        
        // Determine if this is a background update
        let isBackgroundUpdate = UIApplication.shared.applicationState == .background
        
        print("📍 LocationManager: \(isBackgroundUpdate ? "BACKGROUND" : "Foreground") - Location update - Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude)")
        print("📍 LocationManager: \(isBackgroundUpdate ? "BACKGROUND" : "Foreground") - GPS Accuracy: \(Int(location.horizontalAccuracy))m")
        print("📍 LocationManager: \(isBackgroundUpdate ? "BACKGROUND" : "Foreground") - Desired Accuracy: \(Int(desiredAccuracy))m")
        
        // Update our stored values
        lastLocation = location
        lastReportedLocation = location
        
        // Update location through APIManager with both actual and desired accuracy
        let newLocation = Location(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy, // Actual GPS accuracy
            desiredAccuracy: desiredAccuracy, // User's desired privacy-preserving accuracy
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
        // Early return if we lost permission
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            stopUpdatingLocation()
            return
        }
        
        guard let location = locations.last else {
            return
        }
        
        // Determine if this is a background update
        let isBackgroundUpdate = UIApplication.shared.applicationState == .background
        
        // Only update if we've moved significantly or if it's been a while since last update
        if let lastLocation = lastReportedLocation {
            let distance = location.distance(from: lastLocation)
            let timeSinceLastUpdate = Date().timeIntervalSince(lastLocation.timestamp)
            
            // Update if we've moved enough OR if enough time has passed
            if distance < minimumMovementThreshold && timeSinceLastUpdate < updateInterval {
                return
            }
            
            if distance >= minimumMovementThreshold {
                print("📍 LocationManager: \(isBackgroundUpdate ? "BACKGROUND" : "Foreground") - Significant movement detected: \(Int(distance))m")
            }
            
            if timeSinceLastUpdate >= updateInterval {
                print("📍 LocationManager: \(isBackgroundUpdate ? "BACKGROUND" : "Foreground") - Update interval reached: \(Int(timeSinceLastUpdate))s")
            }
        }
        
        // Process the location update
        Task {
            do {
                try await requestLocationUpdate()
                print("📍 LocationManager: \(isBackgroundUpdate ? "BACKGROUND" : "Foreground") - Location successfully updated")
            } catch {
                print("📍 LocationManager: \(isBackgroundUpdate ? "BACKGROUND" : "Foreground") - Location update failed: \(error)")
            }
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
        case .authorizedAlways:
            print("📍 LocationManager: User granted always permission")
            // Reconfigure background updates now that we have permission
            configureBackgroundUpdates()
            startUpdatingLocation()
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
    
    private func handleLocationSettingsChange() {
        Task {
            do {
                try await requestLocationUpdate()
                await apiManager.loadInitialData()
            } catch {
                print("📍 LocationManager: Failed to update location after settings change - \(error)")
            }
        }
    }
    
    @Published var updateInterval: TimeInterval = UserDefaults.standard.double(forKey: "locationUpdateInterval") {
        didSet {
            UserDefaults.standard.set(updateInterval, forKey: "locationUpdateInterval")
            configureBackgroundUpdates()
            handleLocationSettingsChange()
        }
    }
    
    @Published var minimumMovementThreshold: Double = UserDefaults.standard.double(forKey: "minimumMovementThreshold") {
        didSet {
            UserDefaults.standard.set(minimumMovementThreshold, forKey: "minimumMovementThreshold")
            configureBackgroundUpdates()
            handleLocationSettingsChange()
        }
    }
    
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var showingBackgroundPrompt = false
    @Published var backgroundUpdatesEnabled: Bool = UserDefaults.standard.bool(forKey: "backgroundUpdatesEnabled") {
        didSet {
            UserDefaults.standard.set(backgroundUpdatesEnabled, forKey: "backgroundUpdatesEnabled")
            configureBackgroundUpdates()
            handleLocationSettingsChange()
        }
    }
    
    @Published var desiredAccuracy: Double = UserDefaults.standard.double(forKey: "desiredAccuracy") {
        didSet {
            UserDefaults.standard.set(desiredAccuracy, forKey: "desiredAccuracy")
            handleLocationSettingsChange()
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