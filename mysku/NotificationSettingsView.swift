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
            VStack(spacing: 16) {
                // First toggle with icon
                HStack(spacing: 16) {
                    Image(systemName: "bell.badge")
                        .foregroundColor(.blue)
                        .frame(width: 28, height: 28)
                    
                    Toggle("Notify me when I'm near someone", isOn: $receiveNearbyNotifications)
                        .onChange(of: receiveNearbyNotifications) { _ in saveUserSettings() }
                        .tint(.blue)
                }
                
                // Conditional distance selector
                if receiveNearbyNotifications {
                    VStack(spacing: 12) {
                        Divider()
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "ruler")
                                    .foregroundColor(.blue)
                                    .frame(width: 28, height: 28)
                                
                                Text("Notification Distance")
                                
                                Spacer()
                                
                                Picker("", selection: $nearbyNotificationDistance) {
                                    ForEach(notificationDistanceOptions, id: \.value) { option in
                                        Text(option.display).tag(option.value)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: nearbyNotificationDistance) { _ in saveUserSettings() }
                                .labelsHidden()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Second toggle with icon
                HStack(spacing: 16) {
                    Image(systemName: "person.wave.2")
                        .foregroundColor(.blue)
                        .frame(width: 28, height: 28)
                    
                    Toggle("Allow others to see me nearby", isOn: $allowNearbyNotifications)
                        .onChange(of: allowNearbyNotifications) { _ in saveUserSettings() }
                        .tint(.blue)
                }
                
                // Conditional distance selector
                if allowNearbyNotifications {
                    VStack(spacing: 12) {
                        Divider()
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "viewfinder")
                                    .foregroundColor(.blue)
                                    .frame(width: 28, height: 28)
                                
                                Text("Visibility Distance")
                                
                                Spacer()
                                
                                Picker("", selection: $allowNearbyNotificationDistance) {
                                    ForEach(notificationDistanceOptions, id: \.value) { option in
                                        Text(option.display).tag(option.value)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: allowNearbyNotificationDistance) { _ in saveUserSettings() }
                                .labelsHidden()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            HStack {
                Image(systemName: "bell.and.waveform")
                    .foregroundColor(.blue)
                    .font(.footnote)
                Text("NEARBY NOTIFICATIONS")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .textCase(nil)
            }
            .padding(.bottom, 4)
        } footer: {
            Text("Receive a push notification when another user you share a server with is nearby. Define the distance for receiving notifications and for allowing others to be notified about you.")
                .font(.footnote)
                .foregroundColor(Color(.systemGray))
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
    }
    
    private func getDistanceText(_ distance: Double) -> String {
        if distance >= 1000 {
            let km = distance / 1000.0
            return "\(Int(km)) km"
        } else {
            return "\(Int(distance))m"
        }
    }
} 