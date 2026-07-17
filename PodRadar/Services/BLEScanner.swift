import CoreBluetooth
import Foundation

/// Side-effecting CoreBluetooth wrapper. Untestable in CI/simulator (BLE
/// scanning needs real hardware) — keep this file thin and push all logic
/// into Core/ProximityEngine + Core/DeviceRegistry, which the tests cover.
///
/// Scans for ALL nearby BLE peripherals (not just Apple ones) so PodRadar
/// covers headphones, earbuds, watches, and trackers from any brand —
/// the "device finder" positioning, not just AirPods.
@MainActor
final class BLEScanner: NSObject, ObservableObject {
    @Published private(set) var registry = DeviceRegistry()
    @Published private(set) var proximityByDeviceID: [String: ProximityReading] = [:]
    @Published private(set) var isScanning = false
    @Published private(set) var bluetoothState: CBManagerState = .unknown

    /// Fired when a device transitions from in-range to stale, so the
    /// location layer can stamp a last-known-position. Set by the owner
    /// (e.g. AppState) at startup.
    var onDeviceWentStale: ((BLEDevice) -> Void)?

    private var central: CBCentralManager!
    private var engines: [String: ProximityEngine] = [:]
    private var notifiedStaleIDs: Set<String> = []
    private var staleCheckTimer: Timer?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func attachLastKnownLocation(_ location: LastKnownLocation, toDeviceID id: String) {
        registry.attachLastKnownLocation(location, toDeviceID: id)
    }

    func startScanning() {
        guard central.state == .poweredOn else { return }
        // duplicates key: without allowDuplicates the OS coalesces
        // advertisements, which starves the radar of fresh RSSI samples.
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
        staleCheckTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pruneStaleDevices() }
        }
    }

    func stopScanning() {
        central.stopScan()
        isScanning = false
        staleCheckTimer?.invalidate()
        staleCheckTimer = nil
    }

    private func pruneStaleDevices() {
        let now = Date()
        for device in registry.markStaleDevices(asOf: now) {
            guard !notifiedStaleIDs.contains(device.id) else { continue }
            notifiedStaleIDs.insert(device.id)
            onDeviceWentStale?(device)
        }
    }
}

extension BLEScanner: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.bluetoothState = central.state
            if central.state == .poweredOn, self.isScanning == false {
                // no-op: caller decides when to start
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let id = peripheral.identifier.uuidString
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? ""
        let rssi = RSSI.doubleValue

        Task { @MainActor in
            self.notifiedStaleIDs.remove(id)
            self.registry.recordSighting(id: id, name: name, rssi: rssi, at: Date())

            var engine = self.engines[id] ?? ProximityEngine()
            if let reading = engine.ingest(rssi: rssi) {
                self.proximityByDeviceID[id] = reading
            }
            self.engines[id] = engine
        }
    }
}
