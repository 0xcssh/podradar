import XCTest
@testable import PodRadar

final class ProximityEngineTests: XCTestCase {
    func testCloseRSSIYieldsHighProximity() {
        var engine = ProximityEngine()
        let reading = engine.ingest(rssi: -45)
        XCTAssertNotNil(reading)
        XCTAssertGreaterThan(reading!.proximity, 0.8)
    }

    func testFarRSSIYieldsLowProximity() {
        var engine = ProximityEngine()
        let reading = engine.ingest(rssi: -90)
        XCTAssertNotNil(reading)
        XCTAssertLessThan(reading!.proximity, 0.3)
    }

    func testBelowNoiseFloorIsIgnored() {
        var engine = ProximityEngine()
        let reading = engine.ingest(rssi: -110)
        XCTAssertNil(reading)
    }

    func testSmoothingDampensASingleSpike() {
        var engine = ProximityEngine(smoothing: 0.3)
        // Establish a stable baseline far away, then a single close spike —
        // the smoothed proximity should move toward it but not jump all
        // the way there in one sample.
        for _ in 0..<5 { engine.ingest(rssi: -90) }
        let spike = engine.ingest(rssi: -40)!
        let unsmoothedClose = ProximityEngine.proximityScore(forRSSI: -40)
        XCTAssertLessThan(spike.proximity, unsmoothedClose)
    }

    func testTrendDetectsWarmerAndColder() {
        XCTAssertEqual(ProximityEngine.trend(from: 0.5, to: 0.7), .warmer)
        XCTAssertEqual(ProximityEngine.trend(from: 0.7, to: 0.5), .colder)
        XCTAssertEqual(ProximityEngine.trend(from: 0.5, to: 0.51), .steady)
        XCTAssertEqual(ProximityEngine.trend(from: nil, to: 0.5), .steady)
    }

    func testProximityScoreIsMonotonicWithDistance() {
        let near = ProximityEngine.proximityScore(forRSSI: -40)
        let mid = ProximityEngine.proximityScore(forRSSI: -65)
        let far = ProximityEngine.proximityScore(forRSSI: -95)
        XCTAssertGreaterThan(near, mid)
        XCTAssertGreaterThan(mid, far)
    }

    func testProximityScoreClampedToUnitRange() {
        let extremelyClose = ProximityEngine.proximityScore(forRSSI: 0)
        let extremelyFar = ProximityEngine.proximityScore(forRSSI: -100)
        XCTAssertLessThanOrEqual(extremelyClose, 1.0)
        XCTAssertGreaterThanOrEqual(extremelyFar, 0.0)
    }
}
