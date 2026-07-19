import Foundation
import StoreKit

/// StoreKit 2 subscription handling, ported from the RepLock/Loopa pattern.
/// Three products behind `com.awdia.podradar.pro.*`:
/// - `weeklyFullPriceProductID` — NO introductory offer. Used by the first
///   paywall shown after onboarding (and again on subsequent gates until
///   the trial has been exposed once — see CLAUDE.md's two-tier paywall
///   plan, 2026-07-20).
/// - `weeklyProductID` — HAS the 3-day trial. Used only once the user has
///   declined the full-price paywall a second time (the downsell).
/// - `yearlyProductID` — anchor, not currently surfaced in any paywall UI.
///
/// Two separate products exist because an introductory offer is a property
/// of the PRODUCT + the user's Apple-decided eligibility — a client can't
/// show/hide a configured intro offer per screen for the same product ID;
/// StoreKit shows it automatically to eligible users the moment you call
/// `purchase()` on that product.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let weeklyFullPriceProductID = "com.awdia.podradar.pro.weekly.full"
    static let weeklyProductID = "com.awdia.podradar.pro.weekly"
    static let yearlyProductID = "com.awdia.podradar.pro.yearly"

    @Published private(set) var products: [Product] = []
    @Published private(set) var isSubscribed = false
    @Published private(set) var isLoadingProducts = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: [
                Self.weeklyFullPriceProductID,
                Self.weeklyProductID,
                Self.yearlyProductID
            ])
        } catch {
            products = []
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            await handle(verification)
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func refreshEntitlements() async {
        var subscribed = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               [Self.weeklyFullPriceProductID, Self.weeklyProductID, Self.yearlyProductID].contains(transaction.productID) {
                subscribed = true
            }
        }
        isSubscribed = subscribed
    }

    private func handle(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        await transaction.finish()
        await refreshEntitlements()
    }
}
