import Foundation

/// Lets a view outside the Map tab (PreviousLocationsView) request that the
/// Map tab focus on a specific device's last known location — RootView
/// switches to the Map tab when this fires, MapView consumes it to center
/// the camera and then clears it.
@MainActor
final class MapFocusCoordinator: ObservableObject {
    @Published var deviceID: String?

    func focus(onDeviceID deviceID: String) {
        self.deviceID = deviceID
    }
}
