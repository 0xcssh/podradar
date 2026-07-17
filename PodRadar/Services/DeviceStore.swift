import Foundation

/// Persists favorited/named devices (and their last-known-location) across
/// launches. Deliberately NOT the live scan registry — that's rebuilt every
/// session from fresh BLE sightings; this only remembers the small subset
/// the user cared enough to keep.
final class DeviceStore {
    private let defaults: UserDefaults
    private let key = "com.awdia.podradar.savedDevices"

    init(suiteName: String = "group.com.podradar.app") {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func load() -> [BLEDevice] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([BLEDevice].self, from: data)) ?? []
    }

    func save(_ devices: [BLEDevice]) {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        defaults.set(data, forKey: key)
    }
}
