import StoreKit
import SwiftUI

/// Matches PodSpot's real paywall (screen recording reviewed 2026-07-19):
/// radar-pulse hero circle, "Pinpoint Your Device's Exact Location"
/// headline, "Unlock Premium" badge, 3 checkmarked benefit bullets, and a
/// sticky bottom trial CTA. Presented whenever a free user taps a device
/// row (precise tracking is the paid feature — the free tier only shows
/// "Near").
struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    private var weeklyProduct: Product? {
        subscriptionManager.products.first { $0.id == SubscriptionManager.weeklyProductID }
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
                    Text("Terms of Service")
                    Text("Privacy Policy")
                    Button("Already Subscribed?") {
                        Task {
                            await subscriptionManager.refreshEntitlements()
                            if subscriptionManager.isSubscribed { dismiss() }
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(PRColor.lightTextSecondary)
                .padding(.bottom, 12)
            }

            Button {
                dismiss()
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
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
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

    private func benefitRow(_ text: String) -> some View {
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
            guard let weeklyProduct else { return }
            isPurchasing = true
            Task {
                try? await subscriptionManager.purchase(weeklyProduct)
                isPurchasing = false
                if subscriptionManager.isSubscribed { dismiss() }
            }
        } label: {
            VStack(spacing: 2) {
                Text("Continue")
                    .font(.headline)
                Text(trialSubtitle)
                    .font(.caption)
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PRColor.nearBadge, in: Capsule())
        }
        .disabled(weeklyProduct == nil || isPurchasing)
    }

    private var trialSubtitle: String {
        guard let weeklyProduct else { return "3 Days Free Trial" }
        let price = weeklyProduct.displayPrice
        if let intro = weeklyProduct.subscription?.introductoryOffer, intro.paymentMode == .freeTrial {
            let days = intro.period.value
            return "\(days) Days Free Trial, \(price) / week"
        }
        return "\(price) / week"
    }
}
