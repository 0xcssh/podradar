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
        var engine = ProximityEngine()
        // Establish a stable baseline far away, then a single close spike —
        // the smoothed proximity should move toward it but not jump all
        // the way there in one sample, even with a fast attack factor.
        for _ in 0..<5 { engine.ingest(rssi: -90) }
        let spike = engine.ingest(rssi: -40)!
        let unsmoothedClose = ProximityEngine.proximityScore(forRSSI: -40)
        XCTAssertLessThan(spike.proximity, unsmoothedClose)
    }

    func testAttackIsFasterThanRelease() {
        // Same magnitude single-sample jump in both directions — big
        // enough to bypass the median gate (see testLargeJumpBypasses…).
        // Attack (getting closer) should close more of the gap than
        // release (getting farther) — the fix for the field-reported
        // "laggy at 100%" approach feel (2026-07-17).
        var approaching = ProximityEngine()
        for _ in 0..<5 { approaching.ingest(rssi: -70) }
        let afterApproach = approaching.ingest(rssi: -50)!.smoothedRSSI

        var receding = ProximityEngine()
        for _ in 0..<5 { receding.ingest(rssi: -50) }
        let afterRecede = receding.ingest(rssi: -70)!.smoothedRSSI

        let approachGapClosed = abs(afterApproach - (-70))
        let recedeGapClosed = abs(afterRecede - (-50))
        XCTAssertGreaterThan(approachGapClosed, recedeGapClosed)
    }

    func testMedianPreFilterRejectsASingleSmallNoiseSpike() {
        // A stationary device produces RSSI that wobbles a few dB
        // sample-to-sample; one small outlier (real-world multipath/
        // channel-hop noise, below the large-jump bypass threshold)
        // should barely move the reading, not jump the percentage.
        var engine = ProximityEngine()
        for _ in 0..<5 { engine.ingest(rssi: -70) }
        let baseline = engine.smoothedRSSI!

        let spiked = engine.ingest(rssi: -60)! // 10 dB outlier, below the 15 dB bypass threshold
        // Median-of-3 of [-70, -70, -60] is -70, so the spike alone
        // shouldn't move the filtered input at all.
        XCTAssertEqual(spiked.smoothedRSSI, baseline, accuracy: 0.01)
    }

    func testMedianPreFilterAcceptsASustainedSmallChange() {
        // Two consecutive samples at the new (sub-threshold) level should
        // flip the median and let the EMA start tracking it — a real
        // move, not noise.
        var engine = ProximityEngine()
        for _ in 0..<5 { engine.ingest(rssi: -70) }
        engine.ingest(rssi: -60)
        let afterTwo = engine.ingest(rssi: -60)!
        XCTAssertGreaterThan(afterTwo.smoothedRSSI, -70)
    }

    func testLargeJumpBypassesMedianForFastResponse() {
        // Field-reported 2026-07-17 (2nd round): requiring 2 matching
        // samples before accepting ANY change made a real fast approach
        // feel like "huge latency". A single big jump (>= 15 dB, far
        // beyond ordinary multipath jitter) should move the reading
        // immediately, not wait for a second confirming sample.
        var engine = ProximityEngine()
        for _ in 0..<5 { engine.ingest(rssi: -80) }
        let afterOneSample = engine.ingest(rssi: -40)!.smoothedRSSI
        XCTAssertGreaterThan(afterOneSample, -80)
    }

    func testRepeatedCloseSamplesConvergeToNearMaxQuickly() {
        var engine = ProximityEngine()
        for _ in 0..<3 { engine.ingest(rssi: -90) }
        var lastReading: ProximityReading?
        for _ in 0..<4 { lastReading = engine.ingest(rssi: -40) }
        XCTAssertGreaterThan(lastReading!.proximity, 0.9)
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

    func testProximityScoreHasNoPlateauNearMax() {
        // Field-reported 2026-07-17: the old path-loss formula plateaued
        // at -50dBm, so the last stretch of a real approach looked stuck
        // around 75-90% and then "jumped" to 100% instead of climbing
        // continuously. Every dB closer in the close range must still
        // move the score — no two points in this range can tie.
        let scores = stride(from: -55.0, through: -35.0, by: 5.0).map(ProximityEngine.proximityScore(forRSSI:))
        for i in 1..<scores.count {
            XCTAssertGreaterThan(scores[i], scores[i - 1], "expected strictly increasing scores near max")
        }
    }

    func testProximityScoreClampedToUnitRange() {
        let extremelyClose = ProximityEngine.proximityScore(forRSSI: 0)
        let extremelyFar = ProximityEngine.proximityScore(forRSSI: -100)
        XCTAssertLessThanOrEqual(extremelyClose, 1.0)
        XCTAssertGreaterThanOrEqual(extremelyFar, 0.0)
    }
}
