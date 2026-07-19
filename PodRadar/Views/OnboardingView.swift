import SwiftUI

/// Short, sales-focused onboarding — 3 screens, shown once (see
/// PodRadarApp's `hasCompletedOnboarding` flag). Ends by handing control
/// back to the caller, which immediately presents the first paywall gate
/// — the user never reaches the free app without seeing it at least once
/// (CLAUDE.md's two-tier paywall plan, 2026-07-20).
struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var step = 0

    private let stepCount = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                hookStep.tag(0)
                howItWorksStep.tag(1)
                permissionPrimerStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if step < stepCount - 1 {
                    withAnimation { step += 1 }
                } else {
                    onComplete()
                }
            } label: {
                Text(step < stepCount - 1 ? "Continue" : "Get Started")
                    .prPrimaryPill()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(PRColor.background.ignoresSafeArea())
    }

    private var hookStep: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(PRColor.signal.opacity(0.15))
                    .frame(width: 180, height: 180)
                Image(systemName: "airpods")
                    .font(.system(size: 64))
                    .foregroundStyle(PRColor.signal)
            }
            VStack(spacing: 10) {
                Text("Never Lose Your\nAirPods Again")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("That panicked feeling when your earbuds vanish? PodRadar ends it in seconds.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Spacer()
        }
    }

    private var howItWorksStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("How It Works")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 24) {
                onboardingRow(icon: "dot.radiowaves.left.and.right", title: "Scan", subtitle: "PodRadar finds every Bluetooth device around you")
                onboardingRow(icon: "wave.3.right", title: "Follow the Signal", subtitle: "Walk toward it and watch the signal strength rise")
                onboardingRow(icon: "hand.tap.fill", title: "Feel It Get Closer", subtitle: "Haptic pulses speed up as you home in on it")
            }
            .padding(.horizontal, 36)
            Spacer()
            Spacer()
        }
    }

    private func onboardingRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(PRColor.signal)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var permissionPrimerStep: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(PRColor.signal.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(PRColor.signal)
            }
            VStack(spacing: 10) {
                Text("Quick Permission Check")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Next, we'll ask for Bluetooth and Location access — needed to scan for your devices and remember where you found them. Nothing is ever shared.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Spacer()
        }
    }
}
