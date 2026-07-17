import Foundation
import StoreKit

/// StoreKit 2 subscription handling, ported from the RepLock/Loopa pattern.
/// Two products: weekly (primary CTA) and yearly (anchor, makes weekly look
/// cheap on the paywall). Both behind `com.awdia.podradar.pro.*`.
@MainActor
final class SubscriptionManager: ObservableObject {
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
            products = try await Product.products(for: [Self.weeklyProductID, Self.yearlyProductID])
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
               transaction.productID == Self.weeklyProductID || transaction.productID == Self.yearlyProductID {
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
