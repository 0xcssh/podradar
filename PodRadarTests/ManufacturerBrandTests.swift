import XCTest
@testable import PodRadar

final class ManufacturerBrandTests: XCTestCase {
    func testRecognizesSamsung() {
        let data = Data([0x75, 0x00, 0x01, 0x02])
        XCTAssertEqual(ManufacturerBrand.brand(forManufacturerData: data), "Samsung")
    }

    func testRecognizesSony() {
        let data = Data([0x2D, 0x01, 0xAB])
        XCTAssertEqual(ManufacturerBrand.brand(forManufacturerData: data), "Sony")
    }

    func testRecognizesJBL() {
        let data = Data([0x57, 0x00])
        XCTAssertEqual(ManufacturerBrand.brand(forManufacturerData: data), "JBL")
    }

    func testUnknownCompanyIDReturnsNil() {
        let data = Data([0xFF, 0xFF, 0x00])
        XCTAssertNil(ManufacturerBrand.brand(forManufacturerData: data))
    }

    func testNilDataReturnsNil() {
        XCTAssertNil(ManufacturerBrand.brand(forManufacturerData: nil))
    }

    func testTooShortDataReturnsNil() {
        XCTAssertNil(ManufacturerBrand.brand(forManufacturerData: Data([0x75])))
    }
}
