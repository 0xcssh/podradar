import Foundation
import RevenueCat

/// A single purchasable subscription variant, shaped for the UI so
/// paywalls never import RevenueCat directly (same pattern as RepLock —
/// see its Services/SubscriptionManager.swift).
struct SubscriptionOffer: Equatable {
    let displayPrice: String
    /// nil when this variant has no introductory offer.
    let trialDays: Int?
}

/// RevenueCat wrapper for PodRadar's two weekly paywall variants — see
/// CLAUDE.md's two-tier paywall plan (2026-07-20). RevenueCat owns the
/// store plumbing (receipt validation, entitlement computation,
/// transaction finishing); this type keeps a small, view-shaped surface.
///
/// RevenueCat project "PodRadar" (same account as RepLock/Loopa, separate
/// project), scripted via the Management API 2026-07-20: one "pro"
/// entitlement attached to all 3 products
/// (com.awdia.podradar.pro.{weekly,weekly.full,yearly}), one "default"
/// offering with two packages — "weekly_trial" (has the 3-day intro
/// offer) and "weekly_full_price" (no intro offer, same two-ASC-product
/// reasoning as before: an intro offer can't be shown/hidden per screen
/// for one product ID).
@MainActor
final class SubscriptionManager: ObservableObject {
    /// RevenueCat entitlement identifier configured in the dashboard —
    /// the whole app's pro/not-pro routing hangs off this string.
    private static let entitlementID = "pro"
    /// RevenueCat PUBLIC SDK key: designed to ship inside the binary (the
    /// secret Management API key used to script the dashboard setup must
    /// never leave it).
    private static let revenueCatAPIKey = "appl_QyZyTvOVkOBlYnteshTflvcTkJK"

    private static let fullPricePackageID = "weekly_full_price"
    private static let trialPackageID = "weekly_trial"

    @Published private(set) var isSubscribed = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var fullPriceOffer: SubscriptionOffer?
    @Published private(set) var trialOffer: SubscriptionOffer?

    private var fullPricePackage: Package?
    private var trialPackage: Package?

    private var customerInfoTask: Task<Void, Never>?

    init() {
        // Must run before any other Purchases access — `Purchases.shared`
        // traps when the SDK isn't configured yet.
        Purchases.configure(withAPIKey: Self.revenueCatAPIKey)

        customerInfoTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
    }

    deinit {
        customerInfoTask?.cancel()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        guard let offerings = try? await Purchases.shared.offerings() else { return }
        let packages = offerings.current?.availablePackages ?? []
        fullPricePackage = packages.first { $0.identifier == Self.fullPricePackageID }
        trialPackage = packages.first { $0.identifier == Self.trialPackageID }
        fullPriceOffer = fullPricePackage.map(Self.offer(for:))
        trialOffer = trialPackage.map(Self.offer(for:))
    }

    func purchase(variant: PaywallVariant) async throws {
        guard let package = variant == .trial ? trialPackage : fullPricePackage else { return }
        let result = try await Purchases.shared.purchase(package: package)
        guard !result.userCancelled else { return }
        apply(result.customerInfo)
    }

    func refreshEntitlements() async {
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        }
    }

    private func apply(_ info: CustomerInfo) {
        isSubscribed = info.entitlements[Self.entitlementID]?.isActive == true
    }

    private static func offer(for package: Package) -> SubscriptionOffer {
        let product = package.storeProduct
        var trialDays: Int?
        if let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial {
            trialDays = days(from: intro.subscriptionPeriod)
        }
        return SubscriptionOffer(displayPrice: product.localizedPriceString, trialDays: trialDays)
    }

    private static func days(from period: SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return period.value
        }
    }
}
