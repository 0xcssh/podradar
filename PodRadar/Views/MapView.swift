import SwiftUI
import MapKit
import UIKit

/// Last-known-position map — PodRadar's differentiator over PodSpot/
/// Wunderfind/Bickster (see app-marketing-context.md). Shows a pin per
/// device with a recorded LastKnownLocation.
struct MapView: View {
    @EnvironmentObject private var scanner: BLEScanner
    @EnvironmentObject private var locationRecorder: LocationRecorder
    @EnvironmentObject private var mapFocusCoordinator: MapFocusCoordinator
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Group {
                switch locationRecorder.authorizationStatus {
                case .notDetermined:
                    permissionPrompt
                case .denied, .restricted:
                    // Field-reported 2026-07-19: denying (or "Allow Once",
                    // which reverts) the location prompt used to fall
                    // through to a blank, unexplained map with no way to
                    // recover — looked completely broken. iOS won't
                    // re-prompt once denied, so Settings is the only path.
                    deniedState
                case .authorizedWhenInUse, .authorizedAlways:
                    if devicesWithLocation.isEmpty {
                        emptyState
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
                @unknown default:
                    permissionPrompt
                }
            }
            .navigationTitle("Last Seen")
        }
        .onChange(of: mapFocusCoordinator.deviceID) { _, deviceID in
            focusIfNeeded(on: deviceID)
        }
        .onAppear {
            focusIfNeeded(on: mapFocusCoordinator.deviceID)
        }
    }

    /// Centers the camera on a specific device's pin (requested from
    /// PreviousLocationsView) then consumes the request so it doesn't
    /// re-trigger on the next tab switch.
    private func focusIfNeeded(on deviceID: String?) {
        guard let deviceID,
              let device = scanner.registry.allDevices.first(where: { $0.id == deviceID }),
              let location = device.lastKnownLocation else { return }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
        mapFocusCoordinator.deviceID = nil
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
            Button {
                locationRecorder.requestAuthorization()
            } label: {
                Text("Enable Location").prPrimaryPill()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PRColor.background.ignoresSafeArea())
    }

    private var deniedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.6))
            Text("Location access is off, so PodRadar can't remember where a device was last detected.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings").prPrimaryPill()
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PRColor.background.ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.4))
            Text("No locations yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Tap \"Found it!\" on a device to save its location here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PRColor.background.ignoresSafeArea())
    }
}
