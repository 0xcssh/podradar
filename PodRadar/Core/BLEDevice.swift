import Foundation

/// A Bluetooth peripheral PodRadar knows about, independent of CoreBluetooth
/// types so this stays testable without hardware.
struct BLEDevice: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var kind: DeviceKind
    var lastRSSI: Double
    var lastSeen: Date
    /// When this device was FIRST seen this session — immutable, never
    /// touched on subsequent sightings. Used to keep list ordering stable
    /// (see DeviceRegistry.inRangeDevices): sorting by live RSSI made rows
    /// constantly reshuffle as signal strength fluctuated, field-reported
    /// 2026-07-19 as "devices move around in every direction".
    let firstSeen: Date
    var isFavorite: Bool
    var lastKnownLocation: LastKnownLocation?
    /// User-assigned name, overrides the BLE-advertised `name` in the UI.
    /// Persisted locally (DeviceStore) — see `displayName`.
    var customName: String?

    init(
        id: String,
        name: String,
        kind: DeviceKind = .unknown,
        lastRSSI: Double,
        lastSeen: Date,
        firstSeen: Date? = nil,
        isFavorite: Bool = false,
        lastKnownLocation: LastKnownLocation? = nil,
        customName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.lastRSSI = lastRSSI
        self.lastSeen = lastSeen
        self.firstSeen = firstSeen ?? lastSeen
        self.isFavorite = isFavorite
        self.lastKnownLocation = lastKnownLocation
        self.customName = customName
    }

    /// What the UI should show: the user's rename if set, otherwise the
    /// advertised/discovered/brand-guessed name, otherwise a short label
    /// synthesized from the device's own Bluetooth identifier. Field-
    /// reported 2026-07-19 (direct side-by-side with the reference app):
    /// it never shows a bare "Unknown device" — every row has SOME
    /// distinguishing label. Matched by never falling back to a generic
    /// placeholder string here either; `id` is always available and
    /// unique, so this is a "Device XXXXXX" tag derived from it — stable
    /// for the session, at least lets the user tell rows apart even with
    /// zero name/brand information.
    var displayName: String {
        if let customName, !customName.isEmpty { return customName }
        if !name.isEmpty { return name }
        return String(localized: "Device \(Self.shortLabel(fromID: id))")
    }

    private static func shortLabel(fromID id: String) -> String {
        String(id.filter(\.isHexDigit).prefix(6)).uppercased()
    }

    /// Whether this device should still be shown as "in range" given a
    /// staleness window. Devices go silent long before iOS reports a
    /// disconnect, so the radar UI treats "not heard from in N seconds" as
    /// the practical definition of "lost".
    func isStale(asOf now: Date, staleAfter: TimeInterval = 8) -> Bool {
        now.timeIntervalSince(lastSeen) > staleAfter
    }
}

enum DeviceKind: String, Codable, CaseIterable {
    case headphones
    case earbuds
    case watch
    case tracker
    case speaker
    case unknown
}

/// GPS snapshot of where a device was found — saved explicitly by the
/// user from the "Found it!" flow (matches PodSpot's Save Location
/// screen, reviewed 2026-07-19) with an optional description. Field-
/// reported 2026-07-20: an earlier version also auto-stamped this on
/// every in-range→stale transition, which flooded Previous Locations/Map
/// with a pin for every passing stranger's Bluetooth device — removed,
/// this is manual-save only now.
struct LastKnownLocation: Equatable, Codable {
    let latitude: Double
    let longitude: Double
    let recordedAt: Date
    var note: String? = nil
}
