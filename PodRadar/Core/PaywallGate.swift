import Foundation

/// Which paywall the user is currently looking at. `.fullPrice` has no
/// introductory offer; `.trial` has the 3-day free trial.
enum PaywallVariant: Equatable, Codable {
    case fullPrice
    case trial
}

/// Persisted across launches (see Services/DeviceStore).
struct PaywallGateState: Equatable, Codable {
    var hasDeclinedOnce: Bool = false
    var hasSeenTrialOffer: Bool = false
}

/// Pure state machine for the two-tier paywall cascade. See CLAUDE.md's
/// "Planned: onboarding + pulsing CTA + two-tier paywall" (2026-07-20,
/// confirmed with the user across several rounds of clarification —
/// don't re-derive the sequence from first principles, it's non-obvious):
///
/// - Decline #1 ever (of the full-price paywall) → nothing else shown,
///   straight to the free tier.
/// - Decline #2 ever → the trial paywall is shown immediately as a
///   downsell, AND from that point on every future gate goes straight to
///   the trial paywall (never full-price again) until the user subscribes.
enum PaywallGate {
    /// Which variant a NEW gate (onboarding end, tapping a paid feature)
    /// should show, given the current persisted state.
    static func variantForNewGate(state: PaywallGateState) -> PaywallVariant {
        state.hasSeenTrialOffer ? .trial : .fullPrice
    }

    /// Call when the user dismisses a shown paywall without subscribing.
    /// Returns the updated state to persist, and whether the trial
    /// paywall should be presented immediately as a cascade.
    static func handleDecline(
        of variant: PaywallVariant,
        state: PaywallGateState
    ) -> (state: PaywallGateState, showTrialImmediately: Bool) {
        switch variant {
        case .trial:
            // Declining the trial paywall never cascades further.
            return (state, false)
        case .fullPrice:
            var newState = state
            if !state.hasDeclinedOnce {
                newState.hasDeclinedOnce = true
                return (newState, false)
            } else {
                newState.hasSeenTrialOffer = true
                return (newState, true)
            }
        }
    }
}
