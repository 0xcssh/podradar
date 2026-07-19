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
    /// Fired whenever the ignore list changes, so the owner can persist it
    /// (DeviceStore) — the registry itself has no storage dependency.
    var onIgnoredDeviceIDsChanged: ((Set<String>) -> Void)?
    /// Fired whenever a device is renamed, so the owner can persist it.
    var onCustomNamesChanged: (([String: String]) -> Void)?

    private var central: CBCentralManager!
    private var engines: [String: ProximityEngine] = [:]
    private var notifiedStaleIDs: Set<String> = []
    private var staleCheckTimer: Timer?
    /// True between `startScanning()` and `stopScanning()`. A fresh
    /// `CBCentralManager` starts in `.unknown` state and only reaches
    /// `.poweredOn` asynchronously a moment later — calling
    /// `startScanning()` before then used to silently no-op FOREVER
    /// (field-reported 2026-07-17: scan stuck on the empty state, never
    /// recovering). This flag lets `centralManagerDidUpdateState` retry
    /// automatically the moment the radio is actually ready.
    private var wantsToScan = false

    // MARK: - Name probing
    // Field-reported 2026-07-19: "can we fix Unknown device, be more
    // precise?" Most BLE peripherals never include a name in their
    // passive advertisement (only Apple's proximity-pairing beacon is
    // reliably identifiable that way — confirmed 2026-07-17). The actual
    // device name lives in the standard Generic Access service (0x1800),
    // Device Name characteristic (0x2A00), which requires briefly
    // CONNECTING to read — no pairing/bonding needed, read-only, then we
    // disconnect immediately. Only probed once per device, and only for
    // devices strong enough to matter (same floor as the Devices list),
    // so this doesn't spam connection attempts at every faint signal in
    // the building.
    // Referenced from `nonisolated` CBPeripheralDelegate callbacks below —
    // marked `nonisolated` explicitly since static members of a
    // `@MainActor` type are otherwise actor-isolated by default too.
    private nonisolated static let genericAccessServiceUUID = CBUUID(string: "1800")
    private nonisolated static let deviceNameCharacteristicUUID = CBUUID(string: "2A00")
    private static let nameProbeTimeout: TimeInterval = 4

    /// Strong refs required by CoreBluetooth — an unretained CBPeripheral
    /// being connected gets silently dropped.
    private var probingPeripherals: [String: CBPeripheral] = [:]
    private var nameProbeTimeoutTimers: [String: Timer] = [:]
    private var nameProbeAttempted: Set<String> = []

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func attachLastKnownLocation(_ location: LastKnownLocation, toDeviceID id: String) {
        registry.attachLastKnownLocation(location, toDeviceID: id)
    }

    func toggleFavorite(id: String) {
        registry.toggleFavorite(id: id)
    }

    func ignore(id: String) {
        registry.ignore(id: id)
        onIgnoredDeviceIDsChanged?(registry.ignoredDeviceIDs)
    }

    func unignore(id: String) {
        registry.unignore(id: id)
        onIgnoredDeviceIDsChanged?(registry.ignoredDeviceIDs)
    }

    func restoreIgnoredDeviceIDs(_ ids: Set<String>) {
        registry.setIgnoredDeviceIDs(ids)
    }

    func rename(id: String, to newName: String?) {
        registry.rename(id: id, to: newName)
        onCustomNamesChanged?(registry.customNames)
    }

    func restoreCustomNames(_ names: [String: String]) {
        registry.restoreCustomNames(names)
    }

    func startScanning() {
        wantsToScan = true
        guard central.state == .poweredOn, !isScanning else { return }
        beginScan()
    }

    func stopScanning() {
        wantsToScan = false
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        staleCheckTimer?.invalidate()
        staleCheckTimer = nil
    }

    private func beginScan() {
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

    private func pruneStaleDevices() {
        let now = Date()
        for device in registry.markStaleDevices(asOf: now) {
            guard !notifiedStaleIDs.contains(device.id) else { continue }
            notifiedStaleIDs.insert(device.id)
            onDeviceWentStale?(device)
        }
    }

    private func maybeProbeName(for peripheral: CBPeripheral, rssi: Double, hasName: Bool) {
        let id = peripheral.identifier.uuidString
        guard !hasName,
              rssi >= DeviceRegistry.listMinimumRSSI,
              !nameProbeAttempted.contains(id),
              probingPeripherals[id] == nil
        else { return }

        nameProbeAttempted.insert(id)
        probingPeripherals[id] = peripheral
        central.connect(peripheral, options: nil)

        let timer = Timer.scheduledTimer(withTimeInterval: Self.nameProbeTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finishNameProbe(id: id) }
        }
        nameProbeTimeoutTimers[id] = timer
    }

    private func finishNameProbe(id: String) {
        nameProbeTimeoutTimers[id]?.invalidate()
        nameProbeTimeoutTimers.removeValue(forKey: id)
        if let peripheral = probingPeripherals.removeValue(forKey: id) {
            central.cancelPeripheralConnection(peripheral)
        }
    }
}

extension BLEScanner: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.bluetoothState = central.state
            if central.state == .poweredOn, self.wantsToScan, !self.isScanning {
                self.beginScan()
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
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let kind = DeviceKindClassifier.classify(name: name, manufacturerData: manufacturerData)

        Task { @MainActor in
            self.notifiedStaleIDs.remove(id)
            self.registry.recordSighting(id: id, name: name, kind: kind, rssi: rssi, at: Date())
            self.maybeProbeName(for: peripheral, rssi: rssi, hasName: !name.isEmpty)

            var engine = self.engines[id] ?? ProximityEngine()
            if let reading = engine.ingest(rssi: rssi) {
                self.proximityByDeviceID[id] = reading
            }
            self.engines[id] = engine
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            peripheral.delegate = self
            peripheral.discoverServices([Self.genericAccessServiceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let id = peripheral.identifier.uuidString
        Task { @MainActor in self.finishNameProbe(id: id) }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let id = peripheral.identifier.uuidString
        Task { @MainActor in self.finishNameProbe(id: id) }
    }
}

extension BLEScanner: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.genericAccessServiceUUID })
        else {
            let id = peripheral.identifier.uuidString
            Task { @MainActor in self.finishNameProbe(id: id) }
            return
        }
        peripheral.discoverCharacteristics([Self.deviceNameCharacteristicUUID], for: service)
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil,
              let characteristic = service.characteristics?.first(where: { $0.uuid == Self.deviceNameCharacteristicUUID })
        else {
            let id = peripheral.identifier.uuidString
            Task { @MainActor in self.finishNameProbe(id: id) }
            return
        }
        peripheral.readValue(for: characteristic)
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let id = peripheral.identifier.uuidString
        let discoveredName = (error == nil ? characteristic.value.flatMap { String(data: $0, encoding: .utf8) } : nil) ?? ""

        Task { @MainActor in
            if !discoveredName.isEmpty {
                self.registry.updateDiscoveredName(id: id, to: discoveredName)
            }
            self.finishNameProbe(id: id)
        }
    }
}
