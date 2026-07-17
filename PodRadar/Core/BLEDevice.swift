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

/// GPS snapshot recorded the last time a device transitioned from
/// in-range to stale — this is the "last known position" map feature,
/// PodRadar's differentiator over PodSpot/Wunderfind.
struct LastKnownLocation: Equatable, Codable {
    let latitude: Double
    let longitude: Double
    let recordedAt: Date
}
