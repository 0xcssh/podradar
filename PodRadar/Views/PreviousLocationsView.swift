import SwiftUI

/// Shortcut from the Radar hero screen into last-known-location history —
/// mirrors PodSpot's "Previous Locations" button (screenshot reviewed
/// 2026-07-17). Reuses the same data as the Map tab
/// (Core/DeviceRegistry's `lastKnownLocation`) — only devices explicitly
/// saved via "Found it!" → Save Location, never auto-recorded (field-
/// reported 2026-07-20: auto-recording flooded this list with every
/// nearby stranger's device).
struct PreviousLocationsView: View {
    @EnvironmentObject private var scanner: BLEScanner
    @EnvironmentObject private var mapFocusCoordinator: MapFocusCoordinator

    private var devicesWithLocation: [BLEDevice] {
        scanner.registry.allDevices.filter { $0.lastKnownLocation != nil }
    }

    var body: some View {
        Group {
            if devicesWithLocation.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("No previous locations yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Tap \"Found it!\" on a device to save its location here.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(devicesWithLocation) { device in
                    Button {
                        mapFocusCoordinator.focus(onDeviceID: device.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                if let location = device.lastKnownLocation {
                                    Text(location.recordedAt, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                    if let note = location.note, !note.isEmpty {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(PRColor.signal)
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "map.fill")
                                .foregroundStyle(PRColor.signal)
                        }
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(PRColor.card)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
        }
        .background(PRColor.background.ignoresSafeArea())
        .navigationTitle("Previous Locations")
        .navigationBarTitleDisplayMode(.inline)
    }
}
