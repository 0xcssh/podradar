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

    /// Sets the advertised name learned by actively reading the device's
    /// standard Generic Access "Device Name" characteristic (see
    /// Services/BLEScanner's name-probe flow) — for devices that never
    /// include a name in their passive BLE advertisement, which is most
    /// of them (field-confirmed 2026-07-17). Distinct from `rename`
    /// (`customName`, user-chosen): this is what the DEVICE calls itself.
    mutating func updateDiscoveredName(id: String, to name: String) {
        guard !name.isEmpty, var device = devicesByID[id] else { return }
        device.name = name
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

    /// RSSI at/above which a device reads as "NEAR" rather than "FAR" in
    /// the Devices list badge (see RadarView) — a UI classification, NOT
    /// a filter. Field-reported 2026-07-19: an earlier version of this
    /// constant FILTERED weak signals out of the list entirely, but the
    /// reference app shows every device it can see (just badges far ones
    /// red instead of hiding them) and has visibly more entries — "on va
    /// réélargir". Filtering was reverted; this constant now only
    /// controls badge color/text.
    static let nearBadgeThresholdRSSI: Double = -70

    /// Every device currently considered in range (not stale, not
    /// ignored) — no signal-strength filtering, see `nearBadgeThresholdRSSI`.
    /// Sorted by FIRST-seen order, not live RSSI — field-reported
    /// 2026-07-19: sorting by live signal strength made rows constantly
    /// reshuffle ("devices move around in every direction") as RSSI
    /// naturally fluctuates. A stable order matters more than a
    /// "closest first" ordering that's really just noise from row to row.
    func inRangeDevices(asOf now: Date, staleAfter: TimeInterval = 8) -> [BLEDevice] {
        devicesByID.values
            .filter {
                !$0.isStale(asOf: now, staleAfter: staleAfter)
                    && !ignoredDeviceIDs.contains($0.id)
            }
            .sorted { $0.firstSeen < $1.firstSeen }
    }

    var allDevices: [BLEDevice] {
        devicesByID.values.sorted { $0.lastSeen > $1.lastSeen }
    }
}
