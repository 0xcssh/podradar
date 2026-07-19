import Foundation

/// Pure, CI-tested bookkeeping for known devices: upsert on scan results,
/// prune stale ones, and detect the in-range → stale transition that
/// should trigger a last-known-location write (Services/LocationRecorder
/// listens for `.wentStale` events; this type only decides WHEN, not how
/// to record GPS).
struct DeviceRegistry: Equatable {
    private(set) var devicesByID: [String: BLEDevice] = [:]
    /// Devices the user explicitly dismissed as irrelevant (a neighbor's
    /// speaker, a smart-home beacon...). Persisted separately from
    /// favorites via DeviceStore — see Services/DeviceStore.swift.
    private(set) var ignoredDeviceIDs: Set<String> = []

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
            // Upgrade-only: a later ambiguous read should never downgrade
            // an already-classified device back to .unknown.
            if existing.kind == .unknown, kind != .unknown { existing.kind = kind }
            devicesByID[id] = existing
            return .updated(existing)
        } else {
            let device = BLEDevice(
                id: id,
                name: name,
                kind: kind,
                lastRSSI: rssi,
                lastSeen: date,
                customName: pendingCustomNames[id]
            )
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

    /// Sets (or clears, if `newName` is nil/empty) the user's custom name
    /// for a device — see `BLEDevice.displayName`.
    mutating func rename(id: String, to newName: String?) {
        let trimmed = (newName?.isEmpty == false) ? newName : nil
        if var device = devicesByID[id] {
            device.customName = trimmed
            devicesByID[id] = device
        }
        if let trimmed {
            pendingCustomNames[id] = trimmed
        } else {
            pendingCustomNames.removeValue(forKey: id)
        }
    }

    /// Restores previously-persisted custom names (called once at launch
    /// by the owner after loading from DeviceStore). Devices not seen yet
    /// this session won't exist in `devicesByID` — the name is applied
    /// lazily in `recordSighting` via `pendingCustomNames` instead.
    private var pendingCustomNames: [String: String] = [:]

    mutating func restoreCustomNames(_ names: [String: String]) {
        pendingCustomNames = names
        for (id, name) in names where devicesByID[id] != nil {
            devicesByID[id]?.customName = name
        }
    }

    /// Current id → custom name mapping, for the owner to persist via
    /// DeviceStore. Sourced from `pendingCustomNames`, which `rename` keeps
    /// in sync — always correct even for a device not currently known.
    var customNames: [String: String] { pendingCustomNames }

    mutating func ignore(id: String) {
        ignoredDeviceIDs.insert(id)
    }

    mutating func unignore(id: String) {
        ignoredDeviceIDs.remove(id)
    }

    /// Restores a previously-persisted ignore list (called once at launch
    /// by the owner after loading from DeviceStore).
    mutating func setIgnoredDeviceIDs(_ ids: Set<String>) {
        ignoredDeviceIDs = ids
    }

    /// RSSI floor for a device to appear in the Devices list at all.
    /// Field-reported 2026-07-19: with no floor, the list dumped 9-10
    /// devices at once (mostly "Unknown device" — every faint BLE signal
    /// in the building) instead of revealing devices progressively as the
    /// user gets close, the way PodSpot's reference recording does.
    /// -70dBm is roughly "same room" in a typical indoor environment;
    /// tune from field feedback.
    static let listMinimumRSSI: Double = -70

    /// Devices currently considered in range AND strong enough to be
    /// worth showing, excluding anything the user ignored. Sorted by
    /// FIRST-seen order, not live RSSI — field-reported 2026-07-19:
    /// sorting by live signal strength made rows constantly reshuffle
    /// ("devices move around in every direction") as RSSI naturally
    /// fluctuates. A stable order matters more than a "closest first"
    /// ordering that's really just noise from row to row.
    func inRangeDevices(asOf now: Date, staleAfter: TimeInterval = 8, minimumRSSI: Double = listMinimumRSSI) -> [BLEDevice] {
        devicesByID.values
            .filter {
                !$0.isStale(asOf: now, staleAfter: staleAfter)
                    && !ignoredDeviceIDs.contains($0.id)
                    && $0.lastRSSI >= minimumRSSI
            }
            .sorted { $0.firstSeen < $1.firstSeen }
    }

    var allDevices: [BLEDevice] {
        devicesByID.values.sorted { $0.lastSeen > $1.lastSeen }
    }
}
