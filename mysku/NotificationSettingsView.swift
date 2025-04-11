import SwiftUI

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @Binding var receiveNearbyNotifications: Bool
    @Binding var nearbyNotificationDistance: Double
    @Binding var allowNearbyNotifications: Bool
    @Binding var allowNearbyNotificationDistance: Double
    let notificationDistanceOptions: [(value: Double, display: String)]
    let saveUserSettings: () -> Void
    
    var body: some View {
        Section {
            Toggle("Notify me when I'm near someone", isOn: $receiveNearbyNotifications)
                .onChange(of: receiveNearbyNotifications) { _ in saveUserSettings() }
            
            // Conditional Picker for nearby notification distance
            if receiveNearbyNotifications {
                Picker("Notification Distance", selection: $nearbyNotificationDistance) {
                    ForEach(notificationDistanceOptions, id: \.value) { option in
                        Text(option.display).tag(option.value)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: nearbyNotificationDistance) { _ in saveUserSettings() }
            }
            
            Toggle("Notify others when they are near me", isOn: $allowNearbyNotifications)
                .onChange(of: allowNearbyNotifications) { _ in saveUserSettings() }

            // Conditional Picker for allowing nearby notification distance
            if allowNearbyNotifications {
                Picker("Notify Others Within", selection: $allowNearbyNotificationDistance) {
                    ForEach(notificationDistanceOptions, id: \.value) { option in
                        Text(option.display).tag(option.value)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: allowNearbyNotificationDistance) { _ in saveUserSettings() }
            }

        } header: {
            Text("NEARBY NOTIFICATIONS")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .textCase(nil)
        } footer: {
            Text("Receive a push notification when another user you share a server with is nearby. Define the distance for receiving notifications and for allowing others to be notified about you.")
        }
    }
} 