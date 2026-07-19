import SwiftUI
import MapKit

/// Last-known-position map — PodRadar's differentiator over PodSpot/
/// Wunderfind/Bickster (see app-marketing-context.md). Shows a pin per
/// device with a recorded LastKnownLocation.
struct MapView: View {
    @EnvironmentObject private var scanner: BLEScanner
    @EnvironmentObject private var locationRecorder: LocationRecorder
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Group {
                if locationRecorder.authorizationStatus == .notDetermined {
                    permissionPrompt
                } else {
                    Map(position: $cameraPosition) {
                        ForEach(devicesWithLocation) { device in
                            if let location = device.lastKnownLocation {
                                Marker(
                                    device.displayName,
                                    coordinate: CLLocationCoordinate2D(
                                        latitude: location.latitude,
                                        longitude: location.longitude
                                    )
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Last Seen")
        }
    }

    private var devicesWithLocation: [BLEDevice] {
        scanner.registry.allDevices.filter { $0.lastKnownLocation != nil }
    }

    private var permissionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle")
                .font(.system(size: 48))
                .foregroundStyle(PRColor.signal)
            Text("PodRadar can remember where a device was last detected.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Button("Enable Location") {
                locationRecorder.requestAuthorization()
            }
            .prPrimaryPill()
        }
        .padding()
        .background(PRColor.background.ignoresSafeArea())
    }
}
