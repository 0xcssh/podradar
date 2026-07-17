import Foundation

/// Pure, CI-tested signal processing: turns raw RSSI samples into a smoothed
/// proximity score (0...1, 1 = right next to you) and a hot/cold trend.
///
/// No CoreBluetooth dependency — the scanner (Services/BLEScanner) feeds
/// raw RSSI in, this only does math. Keep it that way so device iteration
/// (~15 min per build) is reserved for things that can't be unit-tested.
struct ProximityEngine {
    /// Typical RSSI at 0 distance for BLE beacons/headphones. Devices vary
    /// (~-40 to -55), but a fixed reference keeps the score comparable
    /// across sessions; field-tune once real hardware data comes in.
    static let referenceRSSIAtOneMeter: Double = -50
    /// Path-loss exponent for free space / indoor mixed environment.
    static let pathLossExponent: Double = 2.5
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
    var attackSmoothing: Double = 0.5
    var releaseSmoothing: Double = 0.25

    /// How many recent raw samples the median pre-filter looks at. Real BLE
    /// RSSI swings ±5-10 dB sample-to-sample even with both devices
    /// stationary (multipath, channel hopping) — field-reported 2026-07-17
    /// as "jumps around a lot" once the attack factor above stopped
    /// damping it. A median-of-3 kills single-sample spikes (in EITHER
    /// direction) before they ever reach the EMA, without adding the
    /// directional lag a slower attack factor would.
    private static let medianWindow = 3

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
        let filteredRSSI = recentRawRSSI.sorted()[recentRawRSSI.count / 2]

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

    /// Maps a (smoothed) RSSI value to a 0...1 proximity score using a
    /// standard log-distance path-loss model, clamped to [0, 1].
    static func proximityScore(forRSSI rssi: Double) -> Double {
        // distance_ratio = 10 ^ ((referenceRSSI - rssi) / (10 * n))
        let exponent = (referenceRSSIAtOneMeter - rssi) / (10 * pathLossExponent)
        let distanceRatio = pow(10, exponent)
        // distanceRatio == 1 at the reference point (defined as "very close" -> proximity 1).
        // Larger ratio = farther away -> lower score. Map with a soft inverse curve.
        let score = 1 / (1 + max(0, distanceRatio - 1))
        return min(1, max(0, score))
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
