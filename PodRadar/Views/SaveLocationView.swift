import MapKit
import SwiftUI

/// Matches PodSpot's Save Location screen (screen recording reviewed
/// 2026-07-19): device name, a description field, a small map preview,
/// and a primary save button. Reached from DeviceFinderView's "Found it!"
/// → "Save Location" confirmation.
struct SaveLocationView: View {
    let deviceID: String
    let deviceName: String
    @Binding var path: NavigationPath
    @EnvironmentObject private var scanner: BLEScanner
    @EnvironmentObject private var locationRecorder: LocationRecorder
    @State private var description = ""
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var resolvedLocation: LastKnownLocation?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("Device Name")
                        .font(.caption)
                        .foregroundStyle(PRColor.lightTextSecondary)
                    Text(deviceName)
                        .font(.headline)
                        .foregroundStyle(PRColor.lightText)
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter a description of the location below")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PRColor.lightText)
                    TextField("e.g. Under the couch cushion", text: $description)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PRColor.lightTextSecondary.opacity(0.4), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Map Location")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PRColor.lightText)
                    Map(position: $cameraPosition) {
                        if let resolvedLocation {
                            Marker(deviceName, coordinate: CLLocationCoordinate2D(
                                latitude: resolvedLocation.latitude,
                                longitude: resolvedLocation.longitude
                            ))
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .allowsHitTesting(false)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)

                Button(action: save) {
                    Text("Save Location")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(PRColor.devicesBlue, in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(
            LinearGradient(
                colors: [PRColor.lightBackgroundTop, PRColor.lightBackgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Save Location")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationRecorder.requestAuthorization()
            if let snapshot = locationRecorder.currentLocationSnapshot() {
                resolvedLocation = snapshot
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }

    private func save() {
        var location = resolvedLocation ?? locationRecorder.currentLocationSnapshot()
        location?.note = description.isEmpty ? nil : description
        if let location {
            scanner.attachLastKnownLocation(location, toDeviceID: deviceID)
        }
        path = NavigationPath()
    }
}
