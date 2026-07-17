import CoreLocation
import Foundation

/// Stamps a GPS snapshot the moment a device goes stale (last seen via
/// BLE) — this is the "last known position on a map" differentiator vs
/// PodSpot/Wunderfind/Bickster. "When In Use" authorization only; no
/// background location, no tracking beyond this single use case.
@MainActor
final class LocationRecorder: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Returns the most recent location if fresh enough to be useful for a
    /// "last seen here" pin; nil otherwise (caller should not block on it —
    /// a stale-device event without a location is still worth recording,
    /// just without a map pin).
    func currentLocationSnapshot() -> LastKnownLocation? {
        guard let location = manager.location else { return nil }
        return LastKnownLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            recordedAt: Date()
        )
    }
}

extension LocationRecorder: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }
}
