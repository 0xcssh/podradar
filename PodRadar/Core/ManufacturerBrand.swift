import Foundation

/// Pure, CI-tested lookup from a BLE manufacturer-data company ID to a
/// human-readable brand — a reliable, zero-connection fallback for devices
/// that don't advertise a name. IDs verified 2026-07-19 against the
/// Bluetooth SIG assigned numbers (via Nordic Semiconductor's
/// bluetooth-numbers-database, the standard reference for this data).
///
/// Field-reported the same day: the connect-and-read-GATT-name probe
/// (Services/BLEScanner) "n'a pas l'air fiable" when run automatically in
/// the background for every unnamed device — likely radio contention
/// between the active RSSI scan and simultaneous connect attempts, or
/// devices that simply aren't connectable. This lookup needs none of
/// that: the company ID is sitting right there in the same advertisement
/// packet the RSSI reading already comes from, so it's exactly as
/// reliable as proximity itself.
enum ManufacturerBrand {
    /// Company ID (little-endian first 2 bytes of manufacturer data) → brand name.
    private static let byCompanyID: [UInt16: String] = [
        0x0006: "Microsoft",
        0x004C: "Apple",
        0x0057: "JBL",
        0x0067: "GN Hearing",
        0x0075: "Samsung",
        0x0087: "Garmin",
        0x0089: "GN Hearing",
        0x009E: "Bose",
        0x00CC: "Beats",
        0x00E0: "Google",
        0x012D: "Sony",
        0x0171: "Amazon",
        0x038F: "Xiaomi",
        0x0494: "Sennheiser",
        0x067C: "Tile",
        0x07C9: "Skullcandy"
    ]

    /// Returns a brand name from raw `CBAdvertisementDataManufacturerDataKey`
    /// data, or nil if absent/unrecognized.
    static func brand(forManufacturerData data: Data?) -> String? {
        guard let data, data.count >= 2 else { return nil }
        let companyID = UInt16(data[data.startIndex]) | (UInt16(data[data.startIndex + 1]) << 8)
        return byCompanyID[companyID]
    }
}
