import Foundation

/// Persists favorited/named devices (and their last-known-location) across
/// launches. Deliberately NOT the live scan registry — that's rebuilt every
/// session from fresh BLE sightings; this only remembers the small subset
/// the user cared enough to keep.
final class DeviceStore {
    private let defaults: UserDefaults
    private let devicesKey = "com.awdia.podradar.savedDevices"
    private let ignoredKey = "com.awdia.podradar.ignoredDeviceIDs"
    private let customNamesKey = "com.awdia.podradar.customNames"

    init(suiteName: String = "group.com.podradar.app") {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func load() -> [BLEDevice] {
        guard let data = defaults.data(forKey: devicesKey) else { return [] }
        return (try? JSONDecoder().decode([BLEDevice].self, from: data)) ?? []
    }

    func save(_ devices: [BLEDevice]) {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        defaults.set(data, forKey: devicesKey)
    }

    func loadIgnoredDeviceIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: ignoredKey) ?? [])
    }

    func saveIgnoredDeviceIDs(_ ids: Set<String>) {
        defaults.set(Array(ids), forKey: ignoredKey)
    }

    func loadCustomNames() -> [String: String] {
        (defaults.dictionary(forKey: customNamesKey) as? [String: String]) ?? [:]
    }

    func saveCustomNames(_ names: [String: String]) {
        defaults.set(names, forKey: customNamesKey)
    }
}
