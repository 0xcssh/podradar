import Foundation

/// Pure, CI-tested mapping from proximity to haptic feedback cadence/
/// intensity for the single-device "hot and cold" finder screen. Closer =
/// faster pulses + stronger impact, exactly like a Geiger counter — this
/// is the mechanic that makes an unidentified ("Unknown device") BLE
/// signal still useful: the user doesn't need to know WHAT the device is,
/// just walk until the pulses speed up.
enum HapticPulse {
    enum Intensity: Equatable {
        case light
        case medium
        case heavy
    }

    /// Seconds between pulses at a given proximity (0...1). Clamped to a
    /// sane range so it never goes silent (far) or seizure-fast (near).
    static func interval(forProximity proximity: Double) -> TimeInterval {
        let clamped = min(1, max(0, proximity))
        let minInterval = 0.15
        let maxInterval = 1.2
        return maxInterval - clamped * (maxInterval - minInterval)
    }

    static func intensity(forProximity proximity: Double) -> Intensity {
        switch proximity {
        case ..<0.4: return .light
        case ..<0.75: return .medium
        default: return .heavy
        }
    }
}
