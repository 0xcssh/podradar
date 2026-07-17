import Foundation

/// Pure, CI-tested heuristics for guessing what a BLE peripheral actually
/// IS. Most Bluetooth-audio gear (AirPods included) talks classic
/// Bluetooth (A2DP) for audio, not BLE GATT — the only thing PodRadar
/// ever sees is its BLE advertisement, so this is inherently a best-effort
/// guess, not ground truth. Two signals, in priority order:
///
/// 1. Apple's manufacturer data "Proximity Pairing" message (company ID
///    0x004C, type byte 0x07) — this is the beacon AirPods/Beats emit
///    that every "find my headphones" app in the niche keys off. Reliable
///    even when the advertised name is empty.
/// 2. Name keyword matching for everything else (third-party earbuds,
///    watches, speakers, trackers) — weak but it's what's available.
enum DeviceKindClassifier {
    /// Apple's Bluetooth SIG company identifier.
    static let appleCompanyID: UInt16 = 0x004C
    /// Message type byte for Apple's "Proximity Pairing" advertisement
    /// (the one AirPods/Beats/Powerbeats send).
    static let appleProximityPairingType: UInt8 = 0x07

    /// `manufacturerData` is CoreBluetooth's raw
    /// `CBAdvertisementDataManufacturerDataKey` payload: 2 little-endian
    /// company-ID bytes followed by the vendor-specific payload.
    static func classify(name: String, manufacturerData: Data?) -> DeviceKind {
        if let manufacturerData, isAppleProximityPairing(manufacturerData) {
            return .earbuds
        }
        return classify(name: name)
    }

    static func isAppleProximityPairing(_ data: Data) -> Bool {
        guard data.count >= 3 else { return false }
        let companyID = UInt16(data[data.startIndex]) | (UInt16(data[data.startIndex + 1]) << 8)
        guard companyID == appleCompanyID else { return false }
        let messageType = data[data.startIndex + 2]
        return messageType == appleProximityPairingType
    }

    static func classify(name: String) -> DeviceKind {
        let lowercased = name.lowercased()
        guard !lowercased.isEmpty else { return .unknown }

        if containsAny(lowercased, ["airpod", "earbud", "earphone", "buds", "galaxy buds"]) {
            return .earbuds
        }
        if containsAny(lowercased, ["headphone", "headset", "beats", "bose", "sony wh", "jbl tune", "jbl live"]) {
            return .headphones
        }
        if containsAny(lowercased, ["watch", "band", "fitbit", "garmin"]) {
            return .watch
        }
        if containsAny(lowercased, ["tag", "tile", "tracker", "chipolo"]) {
            return .tracker
        }
        if containsAny(lowercased, ["speaker", "soundlink", "boombox", "megaboom"]) {
            return .speaker
        }
        return .unknown
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}
