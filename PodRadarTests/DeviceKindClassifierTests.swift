import XCTest
@testable import PodRadar

final class DeviceKindClassifierTests: XCTestCase {
    func testAppleProximityPairingDataClassifiesAsEarbuds() {
        // Company ID 0x004C little-endian + type byte 0x07 + arbitrary payload.
        let data = Data([0x4C, 0x00, 0x07, 0x01, 0x02])
        XCTAssertEqual(DeviceKindClassifier.classify(name: "", manufacturerData: data), .earbuds)
    }

    func testNonAppleManufacturerDataFallsBackToNameClassification() {
        let data = Data([0xFF, 0xFF, 0x07])
        XCTAssertEqual(DeviceKindClassifier.classify(name: "Bose QC45", manufacturerData: data), .headphones)
    }

    func testAppleCompanyIDWithDifferentTypeByteIsNotEarbuds() {
        let data = Data([0x4C, 0x00, 0x02]) // e.g. iBeacon type, not proximity pairing
        XCTAssertEqual(DeviceKindClassifier.classify(name: "", manufacturerData: data), .unknown)
    }

    func testEmptyNameAndNoManufacturerDataIsUnknown() {
        XCTAssertEqual(DeviceKindClassifier.classify(name: "", manufacturerData: nil), .unknown)
    }

    func testNameKeywordsMapToExpectedKinds() {
        XCTAssertEqual(DeviceKindClassifier.classify(name: "John's AirPods Pro"), .earbuds)
        XCTAssertEqual(DeviceKindClassifier.classify(name: "Sony WH-1000XM5"), .headphones)
        XCTAssertEqual(DeviceKindClassifier.classify(name: "Apple Watch Series 9"), .watch)
        XCTAssertEqual(DeviceKindClassifier.classify(name: "Tile Mate"), .tracker)
        XCTAssertEqual(DeviceKindClassifier.classify(name: "JBL Boombox 3"), .speaker)
        XCTAssertEqual(DeviceKindClassifier.classify(name: "Random Smart Bulb"), .unknown)
    }

    func testClassificationIsCaseInsensitive() {
        XCTAssertEqual(DeviceKindClassifier.classify(name: "BEATS STUDIO"), .headphones)
    }
}
