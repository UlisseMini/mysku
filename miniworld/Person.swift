import Foundation
import CoreLocation

struct Person: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

// Dummy data
extension Person {
    static let sampleData = [
        Person(name: "Alice", coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),  // NYC
        Person(name: "Bob", coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)),     // London
        Person(name: "Charlie", coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)), // Tokyo
        Person(name: "Diana", coordinate: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093))   // Sydney
    ]
} 