import XCTest
@testable import PodRadar

final class HapticPulseTests: XCTestCase {
    func testIntervalIsShorterWhenCloser() {
        let far = HapticPulse.interval(forProximity: 0.1)
        let near = HapticPulse.interval(forProximity: 0.9)
        XCTAssertGreaterThan(far, near)
    }

    func testIntervalClampedForOutOfRangeInput() {
        XCTAssertEqual(HapticPulse.interval(forProximity: -1), HapticPulse.interval(forProximity: 0))
        XCTAssertEqual(HapticPulse.interval(forProximity: 2), HapticPulse.interval(forProximity: 1))
    }

    func testIntensityBucketsRampUpWithProximity() {
        XCTAssertEqual(HapticPulse.intensity(forProximity: 0.1), .light)
        XCTAssertEqual(HapticPulse.intensity(forProximity: 0.5), .medium)
        XCTAssertEqual(HapticPulse.intensity(forProximity: 0.9), .heavy)
    }
}
