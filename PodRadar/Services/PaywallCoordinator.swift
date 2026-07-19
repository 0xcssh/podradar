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

    /// Set by `decline()` when the cascade rule says the trial variant
    /// should follow. SwiftUI's `.sheet(isPresented:)` won't reliably
    /// re-present if the underlying binding flips false→true within the
    /// same synchronous update that's dismissing it (field-observed
    /// 2026-07-20: the trial paywall silently never appeared) — so the
    /// re-presentation is deferred to the sheet's `onDismiss`, which fires
    /// only after the dismiss transition actually finishes.
    private var pendingCascadeVariant: PaywallVariant?

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
    /// purchase. May queue the trial paywall as a downsell — see
    /// PaywallGate's doc comment for the exact rule — but never presents
    /// it directly; always closes the current sheet first.
    func decline() {
        guard let variant = presentedVariant else { return }
        let result = PaywallGate.handleDecline(of: variant, state: state)
        state = result.state
        store.savePaywallGateState(state)
        pendingCascadeVariant = result.showTrialImmediately ? .trial : nil
        presentedVariant = nil
    }

    /// Call from the paywall sheet's `onDismiss` once it has fully closed.
    /// Re-presents the trial paywall if `decline()` queued a cascade.
    func presentPendingCascadeIfNeeded() {
        guard let pending = pendingCascadeVariant else { return }
        pendingCascadeVariant = nil
        presentedVariant = pending
    }

    /// Call once a purchase succeeds.
    func subscribed() {
        pendingCascadeVariant = nil
        presentedVariant = nil
    }
}
