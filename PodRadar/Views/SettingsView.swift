import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var scanner: BLEScanner

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Subscription")
                        Spacer()
                        Text(subscriptionManager.isSubscribed ? "Pro" : "Free")
                            .foregroundStyle(.secondary)
                    }
                }

                if !ignoredDevices.isEmpty {
                    Section("Ignored Devices") {
                        ForEach(ignoredDevices) { device in
                            HStack {
                                Text(device.displayName)
                                Spacer()
                                Button("Unignore") {
                                    scanner.unignore(id: device.id)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var ignoredDevices: [BLEDevice] {
        scanner.registry.allDevices.filter { scanner.registry.ignoredDeviceIDs.contains($0.id) }
    }
}
