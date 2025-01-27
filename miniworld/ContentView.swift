//
//  ContentView.swift
//  miniworld
//
//  Created by Ulisse Mini on 1/26/25.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
    )
    
    let people = Person.sampleData
    
    var body: some View {
        Map {
            ForEach(people) { person in
                Marker(person.name, coordinate: person.coordinate)
            }
        }
    }
}

#Preview {
    ContentView()
}
