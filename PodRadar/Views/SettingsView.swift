import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var scanner: BLEScanner
    @State private var renamingDeviceID: String?
    @State private var renameText = ""

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

                if !knownDevices.isEmpty {
                    Section("Rename Devices") {
                        ForEach(knownDevices) { device in
                            Button {
                                renameText = device.customName ?? ""
                                renamingDeviceID = device.id
                            } label: {
                                HStack {
                                    Text(device.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "pencil")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
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
            .alert("Rename Device", isPresented: renameAlertBinding) {
                TextField("Device name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let id = renamingDeviceID {
                        scanner.rename(id: id, to: renameText)
                    }
                }
            }
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(get: { renamingDeviceID != nil }, set: { if !$0 { renamingDeviceID = nil } })
    }

    private var knownDevices: [BLEDevice] {
        scanner.registry.allDevices.filter { !scanner.registry.ignoredDeviceIDs.contains($0.id) }
    }

    private var ignoredDevices: [BLEDevice] {
        scanner.registry.allDevices.filter { scanner.registry.ignoredDeviceIDs.contains($0.id) }
    }
}
