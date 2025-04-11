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
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Notify me when I'm near someone", isOn: $receiveNearbyNotifications)
                    .onChange(of: receiveNearbyNotifications) { _ in saveUserSettings() }
                    .tint(.blue)
            }
            .padding(.vertical, 4)
            
            // Conditional Picker for nearby notification distance
            if receiveNearbyNotifications {
                HStack {
                    Text("Notification Distance")
                    Spacer()
                    Picker("", selection: $nearbyNotificationDistance) {
                        ForEach(notificationDistanceOptions, id: \.value) { option in
                            Text(option.display).tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: nearbyNotificationDistance) { _ in saveUserSettings() }
                    .tint(.blue)
                    .fixedSize()
                }
                .padding(.vertical, 4)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Notify others when they are near me", isOn: $allowNearbyNotifications)
                    .onChange(of: allowNearbyNotifications) { _ in saveUserSettings() }
                    .tint(.blue)
            }
            .padding(.vertical, 4)

            // Conditional Picker for allowing nearby notification distance
            if allowNearbyNotifications {
                HStack {
                    Text("Notify Others Within")
                    Spacer()
                    Picker("", selection: $allowNearbyNotificationDistance) {
                        ForEach(notificationDistanceOptions, id: \.value) { option in
                            Text(option.display).tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: allowNearbyNotificationDistance) { _ in saveUserSettings() }
                    .tint(.blue)
                    .fixedSize()
                }
                .padding(.vertical, 4)
            }

        } header: {
            Text("NEARBY NOTIFICATIONS")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .textCase(nil)
                .padding(.bottom, 4)
        } footer: {
            Text("Receive a push notification when another user you share a server with is nearby. Define the distance for receiving notifications and for allowing others to be notified about you.")
                .font(.footnote)
                .foregroundColor(Color(.systemGray))
                .padding(.top, 4)
        }
    }
} 