import XCTest
@testable import PodRadar

final class DeviceRegistryTests: XCTestCase {
    func testRecordSightingAddsNewDevice() {
        var registry = DeviceRegistry()
        let change = registry.recordSighting(id: "A", name: "AirPods Pro", rssi: -50, at: .now)
        guard case .added(let device) = change else {
            return XCTFail("expected .added")
        }
        XCTAssertEqual(device.id, "A")
        XCTAssertEqual(registry.allDevices.count, 1)
    }

    func testRecordSightingUpdatesKnownDevice() {
        var registry = DeviceRegistry()
        registry.recordSighting(id: "A", name: "AirPods Pro", rssi: -70, at: .now)
        let change = registry.recordSighting(id: "A", name: "AirPods Pro", rssi: -45, at: .now.addingTimeInterval(1))
        guard case .updated(let device) = change else {
            return XCTFail("expected .updated")
        }
        XCTAssertEqual(device.lastRSSI, -45)
        XCTAssertEqual(registry.allDevices.count, 1)
    }

    func testEmptyNameOnUpdateKeepsPreviousName() {
        var registry = DeviceRegistry()
        registry.recordSighting(id: "A", name: "AirPods Pro", rssi: -70, at: .now)
        registry.recordSighting(id: "A", name: "", rssi: -60, at: .now)
        XCTAssertEqual(registry.allDevices.first?.name, "AirPods Pro")
    }

    func testInRangeDevicesExcludesStaleOnes() {
        var registry = DeviceRegistry()
        let now = Date()
        registry.recordSighting(id: "fresh", name: "Fresh", rssi: -50, at: now)
        registry.recordSighting(id: "stale", name: "Stale", rssi: -50, at: now.addingTimeInterval(-30))

        let inRange = registry.inRangeDevices(asOf: now, staleAfter: 8)
        XCTAssertEqual(inRange.map(\.id), ["fresh"])
    }

    func testInRangeDevicesSortedClosestFirst() {
        var registry = DeviceRegistry()
        let now = Date()
        registry.recordSighting(id: "far", name: "Far", rssi: -80, at: now)
        registry.recordSighting(id: "near", name: "Near", rssi: -45, at: now)

        let inRange = registry.inRangeDevices(asOf: now)
        XCTAssertEqual(inRange.map(\.id), ["near", "far"])
    }

    func testMarkStaleDevicesReturnsOnlyStaleOnes() {
        var registry = DeviceRegistry()
        let now = Date()
        registry.recordSighting(id: "fresh", name: "Fresh", rssi: -50, at: now)
        registry.recordSighting(id: "stale", name: "Stale", rssi: -50, at: now.addingTimeInterval(-30))

        let stale = registry.markStaleDevices(asOf: now, staleAfter: 8)
        XCTAssertEqual(stale.map(\.id), ["stale"])
    }

    func testAttachLastKnownLocation() {
        var registry = DeviceRegistry()
        registry.recordSighting(id: "A", name: "AirPods Pro", rssi: -70, at: .now)
        let location = LastKnownLocation(latitude: 48.85, longitude: 2.35, recordedAt: .now)
        registry.attachLastKnownLocation(location, toDeviceID: "A")
        XCTAssertEqual(registry.allDevices.first?.lastKnownLocation, location)
    }

    func testToggleFavorite() {
        var registry = DeviceRegistry()
        registry.recordSighting(id: "A", name: "AirPods Pro", rssi: -70, at: .now)
        registry.toggleFavorite(id: "A")
        XCTAssertTrue(registry.allDevices.first!.isFavorite)
        registry.toggleFavorite(id: "A")
        XCTAssertFalse(registry.allDevices.first!.isFavorite)
    }
}
