import SwiftUI

/// Matches PodSpot's real paywall (screen recording reviewed 2026-07-19):
/// radar-pulse hero circle, "Pinpoint Your Device's Exact Location"
/// headline, "Unlock Premium" badge, 3 checkmarked benefit bullets, and a
/// sticky bottom CTA. Two variants — see CLAUDE.md's two-tier paywall plan
/// (2026-07-20): `.fullPrice` has no introductory offer (shown first, on
/// every gate until the trial has been exposed once); `.trial` has the
/// 3-day free trial (the downsell, shown after a 2nd decline and from
/// then on). The X/swipe-to-dismiss action routes through
/// PaywallCoordinator.decline(), which decides whether that cascades
/// straight into the trial variant instead of actually closing.
struct PaywallView: View {
    let variant: PaywallVariant

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    @State private var isPurchasing = false

    init(variant: PaywallVariant = .trial) {
        self.variant = variant
    }

    private var offer: SubscriptionOffer? {
        switch variant {
        case .fullPrice: return subscriptionManager.fullPriceOffer
        case .trial: return subscriptionManager.trialOffer
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [PRColor.lightBackgroundTop, PRColor.lightBackgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    radarHero
                        .padding(.top, 50)

                    if variant == .trial {
                        specialOfferBanner
                    }

                    VStack(spacing: 10) {
                        Text("Pinpoint Your Device's\nExact Location")
                            .font(.title2.bold())
                            .foregroundStyle(PRColor.lightText)
                            .multilineTextAlignment(.center)

                        Text("Unlock Premium")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(PRColor.nearBadge, in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        benefitRow("Unlock unlimited scans")
                        benefitRow("See precise signal strength")
                        benefitRow("Act quickly before device battery diminishes")
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                    Spacer(minLength: 24)
                }
                .padding(.bottom, 180)
            }

            VStack(spacing: 12) {
                Spacer()
                continueButton
                    .padding(.horizontal, 20)

                HStack(spacing: 16) {
                    // Apple requires functional links to both on any
                    // subscription screen (Guideline 3.1.2) — these were
                    // plain, non-tappable Text before (field-reported
                    // 2026-07-20).
                    Link(destination: PodRadarLegal.termsURL) {
                        Text("Terms of Service")
                    }
                    Link(destination: PodRadarLegal.privacyURL) {
                        Text("Privacy Policy")
                    }
                    Button("Already Subscribed?") {
                        Task {
                            await subscriptionManager.refreshEntitlements()
                            if subscriptionManager.isSubscribed { paywallCoordinator.subscribed() }
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(PRColor.lightTextSecondary)
                .padding(.bottom, 12)
            }

            Button {
                paywallCoordinator.decline()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(PRColor.lightText)
                    .padding(10)
                    .background(.white.opacity(0.7), in: Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 12)
        }
        .task {
            if subscriptionManager.fullPriceOffer == nil && subscriptionManager.trialOffer == nil {
                await subscriptionManager.loadProducts()
            }
        }
    }

    /// True once loading has finished at least once and still found
    /// nothing — distinct from "still loading" so the button can offer a
    /// retry instead of sitting silently disabled forever. New products
    /// can take a few minutes to propagate after creation in App Store
    /// Connect/RevenueCat (field-observed 2026-07-19); this gives the
    /// user something to act on instead of force-quitting the app.
    private var productLoadFailed: Bool {
        !subscriptionManager.isLoadingProducts && offer == nil
    }

    /// Only shown on the `.trial` variant — the downsell after a 2nd
    /// decline (CLAUDE.md's two-tier paywall plan, 2026-07-20). Makes the
    /// offer visually distinct from the full-price paywall the user just
    /// dismissed, so it reads as a genuine better deal rather than the
    /// same screen shown again.
    private var specialOfferBanner: some View {
        VStack(spacing: 6) {
            Text("SPECIAL OFFER")
                .font(.caption.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(PRColor.signal, in: Capsule())

            Text("Just for you — try 3 days free before you pay a thing.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(PRColor.lightTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var radarHero: some View {
        ZStack {
            ForEach(0..<3) { ring in
                Circle()
                    .fill(PRColor.devicesBlue.opacity(0.22 - Double(ring) * 0.06))
                    .frame(width: 220 - CGFloat(ring) * 50, height: 220 - CGFloat(ring) * 50)
            }
            Circle()
                .fill(PRColor.devicesBlueDeep)
                .frame(width: 90, height: 90)
            Image(systemName: "bolt.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white)
        }
    }

    // LocalizedStringKey (not String) so Text(text) below auto-localizes —
    // a String parameter would take Text's verbatim overload instead,
    // even when call sites pass literals.
    private func benefitRow(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PRColor.nearBadge)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PRColor.lightText)
            Spacer()
        }
    }

    private var continueButton: some View {
        Button {
            if offer != nil {
                isPurchasing = true
                Task {
                    try? await subscriptionManager.purchase(variant: variant)
                    isPurchasing = false
                    if subscriptionManager.isSubscribed { paywallCoordinator.subscribed() }
                }
            } else {
                Task { await subscriptionManager.loadProducts() }
            }
        } label: {
            Group {
                if subscriptionManager.isLoadingProducts || isPurchasing {
                    ProgressView().tint(.white)
                } else if productLoadFailed {
                    Text("Couldn't load pricing — Tap to Retry")
                        .font(.headline)
                } else {
                    VStack(spacing: 2) {
                        Text(continueTitle)
                            .font(.headline)
                        Text(priceSubtitle)
                            .font(.caption)
                            .opacity(0.9)
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PRColor.nearBadge, in: Capsule())
        }
        .disabled(isPurchasing || subscriptionManager.isLoadingProducts)
    }

    /// Trial variant leads with the offer itself ("Try for Free for 3
    /// Days") rather than a generic "Continue" — field-requested
    /// 2026-07-20 so the CTA states the deal up front instead of burying
    /// it in the caption underneath. Wording refined 2026-07-23 to read
    /// more naturally than the terser "Try 3 Days Free".
    private var continueTitle: LocalizedStringKey {
        guard let trialDays = offer?.trialDays else { return "Continue" }
        return "Try for Free for \(trialDays) Days"
    }

    // String(localized:) with interpolation — see CantSeeDeviceView for
    // why (String variables don't auto-localize like Text("literal")
    // does). The interpolated argument types become %lld/%@ placeholders
    // in the catalog key.
    private var priceSubtitle: String {
        guard let offer else {
            return variant == .trial ? String(localized: "3 Days Free Trial") : String(localized: "Weekly subscription")
        }
        if offer.trialDays != nil {
            return String(localized: "then \(offer.displayPrice) / week")
        }
        return String(localized: "\(offer.displayPrice) / week")
    }
}
