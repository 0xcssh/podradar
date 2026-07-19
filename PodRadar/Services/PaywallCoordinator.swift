import Foundation

/// Drives the two-tier paywall cascade (Core/PaywallGate) from the UI —
/// see CLAUDE.md's "Planned: onboarding + pulsing CTA + two-tier paywall"
/// (2026-07-20) for the full sequence. Any screen that needs to gate a
/// paid feature calls `requestGate()`; the paywall sheet observes
/// `presentedVariant` and calls `decline()`/`subscribed()` on dismissal.
@MainActor
final class PaywallCoordinator: ObservableObject {
    @Published private(set) var presentedVariant: PaywallVariant?

    private var state: PaywallGateState
    private let store: DeviceStore

    init(store: DeviceStore) {
        self.store = store
        self.state = store.loadPaywallGateState()
    }

    /// Call whenever a paid feature is gated (onboarding end, tapping a
    /// device while not subscribed, the manual "Unlock Premium" entry
    /// point). Presents whichever variant the current state calls for.
    func requestGate() {
        presentedVariant = PaywallGate.variantForNewGate(state: state)
    }

    /// Call when the presented paywall is dismissed (X) without a
    /// purchase. May immediately re-present the trial paywall as a
    /// downsell — see PaywallGate's doc comment for the exact rule.
    func decline() {
        guard let variant = presentedVariant else { return }
        let result = PaywallGate.handleDecline(of: variant, state: state)
        state = result.state
        store.savePaywallGateState(state)
        presentedVariant = result.showTrialImmediately ? .trial : nil
    }

    /// Call once a purchase succeeds.
    func subscribed() {
        presentedVariant = nil
    }
}
