import Foundation

/// Pure, CI-tested signal processing: turns raw RSSI samples into a smoothed
/// proximity score (0...1, 1 = right next to you) and a hot/cold trend.
///
/// No CoreBluetooth dependency — the scanner (Services/BLEScanner) feeds
/// raw RSSI in, this only does math. Keep it that way so device iteration
/// (~15 min per build) is reserved for things that can't be unit-tested.
struct ProximityEngine {
    /// RSSI treated as "as far as useful" (0%). Below the noise floor is
    /// discarded entirely, not just scored 0.
    static let farRSSI: Double = -90
    /// RSSI treated as "point-blank" (100%). Field-tuned 2026-07-17: the
    /// previous model (a path-loss formula that plateaued at -50dBm) made
    /// the LAST stretch of a real approach invisible — proximity looked
    /// stuck around 75-90% and then "jumped" to 100% once the smoothed
    /// value finally crossed the plateau threshold, instead of climbing
    /// continuously. A simple, wide, continuous ramp all the way down to
    /// near-touching RSSI removes that dead zone.
    static let closeRSSI: Double = -35
    /// Below this RSSI a reading is discarded as noise/out-of-range rather
    /// than fed into the filter.
    static let noiseFloorRSSI: Double = -100

    /// Asymmetric exponential moving average: fast "attack" when a sample
    /// says the device got CLOSER, slow "release" when it says farther.
    /// Field-tested 2026-07-17: a symmetric filter (0.3 both ways) felt
    /// laggy reaching 100% while walking toward the device — human
    /// perception tolerates a snappy "getting warmer" far more than it
    /// tolerates flicker on "getting colder", so the two directions don't
    /// need matching time constants.
    var attackSmoothing: Double = 0.6
    var releaseSmoothing: Double = 0.25

    /// How many recent raw samples the median pre-filter looks at. Real BLE
    /// RSSI swings a few dB sample-to-sample even with both devices
    /// stationary (multipath, channel hopping) — field-reported 2026-07-17
    /// as "jumps around a lot" before this existed. A median-of-3 kills
    /// single-sample spikes before they ever reach the EMA.
    private static let medianWindow = 3
    /// A single-sample deviation at or above this is treated as genuine
    /// movement, not noise, and bypasses the median gate entirely — field-
    /// reported 2026-07-17 (2nd round): the median's mandatory "2 matching
    /// samples to accept a change" made a real fast approach feel like
    /// "huge latency". Ordinary multipath jitter rarely swings this far in
    /// one sample; a real step toward/away from the device easily does.
    private static let largeJumpThreshold: Double = 15

    private var recentRawRSSI: [Double] = []
    private(set) var smoothedRSSI: Double?
    private(set) var previousProximity: Double?

    /// Feeds one raw RSSI sample. Returns nil if the sample is below the
    /// noise floor (caller should ignore it, not treat it as "very far").
    @discardableResult
    mutating func ingest(rssi: Double) -> ProximityReading? {
        guard rssi >= Self.noiseFloorRSSI else { return nil }

        recentRawRSSI.append(rssi)
        if recentRawRSSI.count > Self.medianWindow {
            recentRawRSSI.removeFirst(recentRawRSSI.count - Self.medianWindow)
        }
        let medianRSSI = recentRawRSSI.sorted()[recentRawRSSI.count / 2]

        let filteredRSSI: Double
        if let previous = smoothedRSSI, abs(rssi - previous) >= Self.largeJumpThreshold {
            filteredRSSI = rssi
        } else {
            filteredRSSI = medianRSSI
        }

        if let previous = smoothedRSSI {
            // Higher (less negative) RSSI == closer == attack; lower == release.
            let factor = filteredRSSI > previous ? attackSmoothing : releaseSmoothing
            smoothedRSSI = previous + factor * (filteredRSSI - previous)
        } else {
            smoothedRSSI = filteredRSSI
        }
        guard let smoothed = smoothedRSSI else { return nil }

        let proximity = Self.proximityScore(forRSSI: smoothed)
        let trend = Self.trend(from: previousProximity, to: proximity)
        previousProximity = proximity

        return ProximityReading(proximity: proximity, trend: trend, smoothedRSSI: smoothed)
    }

    /// Maps a (smoothed) RSSI value to a 0...1 proximity score: a smooth
    /// continuous ramp between `farRSSI` (0%) and `closeRSSI` (100%), with
    /// no plateau in between — see `closeRSSI` doc for why that matters.
    static func proximityScore(forRSSI rssi: Double) -> Double {
        let t = (rssi - farRSSI) / (closeRSSI - farRSSI)
        let clamped = min(1, max(0, t))
        // Smoothstep: gentler acceleration at both ends than a straight
        // line, without reintroducing a flat plateau anywhere.
        return clamped * clamped * (3 - 2 * clamped)
    }

    /// Compares two proximity scores and classifies the movement direction.
    /// A dead zone avoids flickering hot/cold on RSSI jitter.
    static func trend(from previous: Double?, to current: Double, deadZone: Double = 0.03) -> ProximityTrend {
        guard let previous else { return .steady }
        let delta = current - previous
        if delta > deadZone { return .warmer }
        if delta < -deadZone { return .colder }
        return .steady
    }
}

struct ProximityReading: Equatable {
    let proximity: Double
    let trend: ProximityTrend
    let smoothedRSSI: Double

    /// 0...100 for display.
    var percent: Int { Int((proximity * 100).rounded()) }
}

enum ProximityTrend: Equatable {
    case warmer
    case colder
    case steady
}
