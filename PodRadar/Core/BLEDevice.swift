import Foundation

/// A Bluetooth peripheral PodRadar knows about, independent of CoreBluetooth
/// types so this stays testable without hardware.
struct BLEDevice: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var kind: DeviceKind
    var lastRSSI: Double
    var lastSeen: Date
    var isFavorite: Bool
    var lastKnownLocation: LastKnownLocation?

    init(
        id: String,
        name: String,
        kind: DeviceKind = .unknown,
        lastRSSI: Double,
        lastSeen: Date,
        isFavorite: Bool = false,
        lastKnownLocation: LastKnownLocation? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.lastRSSI = lastRSSI
        self.lastSeen = lastSeen
        self.isFavorite = isFavorite
        self.lastKnownLocation = lastKnownLocation
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

/// GPS snapshot of where a device was found — either stamped
/// automatically on the in-range→stale transition, or saved explicitly by
/// the user from the "Found it!" flow (matches PodSpot's Save Location
/// screen, reviewed 2026-07-19) with an optional description.
struct LastKnownLocation: Equatable, Codable {
    let latitude: Double
    let longitude: Double
    let recordedAt: Date
    var note: String? = nil
}
