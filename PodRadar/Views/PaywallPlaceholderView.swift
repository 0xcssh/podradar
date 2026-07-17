import SwiftUI

/// Stub so the "Unlock Premium" pill has somewhere to go without a dead
/// tap. Real paywall (StoreKit product, PodSpot-style radar-pulse hero +
/// benefit bullets + trial CTA) is M4 — see SPEC.md / app-marketing-context.md.
struct PaywallPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.system(size: 40))
                .foregroundStyle(PRColor.premium)
            Text("PodRadar Pro")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Coming soon.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PRColor.background.ignoresSafeArea())
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
    }
}
