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
                        .foregroundColor(AppTheme.primaryColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(AppTheme.primaryColor.opacity(0.1))
                                .frame(width: 36, height: 36)
                        )
                    
                    Toggle("Notify me when I'm near someone", isOn: $receiveNearbyNotifications)
                        .onChange(of: receiveNearbyNotifications) { _ in saveUserSettings() }
                        .tint(AppTheme.primaryColor)
                }
                .padding(.vertical, 4)
                
                // Conditional distance selector
                if receiveNearbyNotifications {
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.horizontal, 8)
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "ruler")
                                    .foregroundColor(AppTheme.primaryColor)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(AppTheme.primaryColor.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                    )
                                
                                Text("Notification Distance")
                                    .font(.body)
                                
                                Spacer()
                                
                                Picker("", selection: $nearbyNotificationDistance) {
                                    ForEach(notificationDistanceOptions, id: \.value) { option in
                                        Text(option.display).tag(option.value)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: nearbyNotificationDistance) { _ in saveUserSettings() }
                                .labelsHidden()
                                .accentColor(AppTheme.primaryColor)
                            }
                            .withPickerRow(value: getDistanceText(nearbyNotificationDistance))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
                
                Divider()
                    .padding(.horizontal, 8)
                
                // Second toggle with icon
                HStack(spacing: 16) {
                    Image(systemName: "person.wave.2")
                        .foregroundColor(AppTheme.primaryColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(AppTheme.primaryColor.opacity(0.1))
                                .frame(width: 36, height: 36)
                        )
                    
                    Toggle("Allow others to see me nearby", isOn: $allowNearbyNotifications)
                        .onChange(of: allowNearbyNotifications) { _ in saveUserSettings() }
                        .tint(AppTheme.primaryColor)
                }
                .padding(.vertical, 4)
                
                // Conditional distance selector
                if allowNearbyNotifications {
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.horizontal, 8)
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "viewfinder")
                                    .foregroundColor(AppTheme.primaryColor)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(AppTheme.primaryColor.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                    )
                                
                                Text("Visibility Distance")
                                    .font(.body)
                                
                                Spacer()
                                
                                Picker("", selection: $allowNearbyNotificationDistance) {
                                    ForEach(notificationDistanceOptions, id: \.value) { option in
                                        Text(option.display).tag(option.value)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: allowNearbyNotificationDistance) { _ in saveUserSettings() }
                                .labelsHidden()
                                .accentColor(AppTheme.primaryColor)
                            }
                            .withPickerRow(value: getDistanceText(allowNearbyNotificationDistance))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 8)
        } header: {
            HStack {
                Image(systemName: "bell.and.waveform")
                    .foregroundColor(AppTheme.primaryColor)
                    .font(.footnote)
                Text("NEARBY NOTIFICATIONS")
                    .sectionHeader()
            }
        } footer: {
            HStack(alignment: .top) {
                Image(systemName: "info.circle")
                    .foregroundColor(AppTheme.textSecondary)
                    .font(.caption)
                    .padding(.top, 3)
                
                Text("Receive a push notification when another user you share a server with is nearby. Define the distance for receiving notifications and for allowing others to be notified about you.")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.top, 4)
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