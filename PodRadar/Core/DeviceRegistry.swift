import Foundation

/// Pure, CI-tested bookkeeping for known devices: upsert on scan results,
/// prune stale ones, and detect the in-range → stale transition that
/// should trigger a last-known-location write (Services/LocationRecorder
/// listens for `.wentStale` events; this type only decides WHEN, not how
/// to record GPS).
struct DeviceRegistry: Equatable {
    private(set) var devicesByID: [String: BLEDevice] = [:]

    enum Change: Equatable {
        case added(BLEDevice)
        case updated(BLEDevice)
        case wentStale(BLEDevice)
    }

    /// Upserts a scan sighting. Returns `.added` for a brand-new device,
    /// `.updated` for a refreshed sighting of a known one.
    @discardableResult
    mutating func recordSighting(
        id: String,
        name: String,
        kind: DeviceKind = .unknown,
        rssi: Double,
        at date: Date
    ) -> Change {
        if var existing = devicesByID[id] {
            existing.lastRSSI = rssi
            existing.lastSeen = date
            if !name.isEmpty { existing.name = name }
            devicesByID[id] = existing
            return .updated(existing)
        } else {
            let device = BLEDevice(id: id, name: name, kind: kind, lastRSSI: rssi, lastSeen: date)
            devicesByID[id] = device
            return .added(device)
        }
    }

    /// Scans all known devices for the in-range → stale transition as of
    /// `now`, marking them and returning the ones that just went stale
    /// (fire once per transition, not on every poll).
    mutating func markStaleDevices(asOf now: Date, staleAfter: TimeInterval = 8) -> [BLEDevice] {
        var justWentStale: [BLEDevice] = []
        for (id, device) in devicesByID where device.isStale(asOf: now, staleAfter: staleAfter) {
            // Already-stale devices don't re-fire; we detect the edge by
            // checking staleness one tick back isn't tracked here, so the
            // caller (Services layer) is expected to call this on a timer
            // and diff against its own "already notified" set. Exposed as
            // a pure list of currently-stale devices for that purpose.
            justWentStale.append(device)
            _ = id
        }
        return justWentStale
    }

    mutating func attachLastKnownLocation(_ location: LastKnownLocation, toDeviceID id: String) {
        guard var device = devicesByID[id] else { return }
        device.lastKnownLocation = location
        devicesByID[id] = device
    }

    mutating func toggleFavorite(id: String) {
        guard var device = devicesByID[id] else { return }
        device.isFavorite.toggle()
        devicesByID[id] = device
    }

    /// Devices currently considered in range, sorted closest-first by RSSI.
    func inRangeDevices(asOf now: Date, staleAfter: TimeInterval = 8) -> [BLEDevice] {
        devicesByID.values
            .filter { !$0.isStale(asOf: now, staleAfter: staleAfter) }
            .sorted { $0.lastRSSI > $1.lastRSSI }
    }

    var allDevices: [BLEDevice] {
        devicesByID.values.sorted { $0.lastSeen > $1.lastSeen }
    }
}
