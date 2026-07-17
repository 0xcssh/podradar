import SwiftUI
import UIKit

/// Full-screen hot/cold finder for ONE device — the mechanic that makes an
/// unidentified ("Unknown device") BLE signal still useful: no need to
/// know what it is, just walk until the pulses speed up. Reuses the
/// concentric radar-ring visual language from PodSpot's onboarding/paywall
/// (see app-marketing-context.md) as the primary screen, not just chrome.
struct DeviceFinderView: View {
    let deviceID: String
    @EnvironmentObject private var scanner: BLEScanner
    @State private var pulse = false
    @State private var hapticTimer: Timer?
    private let feedback = UIImpactFeedbackGenerator(style: .light)

    private var device: BLEDevice? {
        scanner.registry.allDevices.first { $0.id == deviceID }
    }

    private var reading: ProximityReading? {
        scanner.proximityByDeviceID[deviceID]
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                ForEach(0..<3) { ring in
                    Circle()
                        .stroke(PRColor.signal.opacity(0.25 - Double(ring) * 0.07), lineWidth: 2)
                        .frame(width: ringDiameter(for: ring), height: ringDiameter(for: ring))
                        .scaleEffect(pulse ? 1.15 : 0.95)
                        .animation(
                            .easeInOut(duration: pulseDuration).repeatForever(autoreverses: true),
                            value: pulse
                        )
                }
                Circle()
                    .fill(PRColor.signal.opacity(0.15))
                    .frame(width: 140)
                VStack(spacing: 4) {
                    Text("\(reading?.percent ?? 0)%")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Image(systemName: "bolt.horizontal.fill")
                        .foregroundStyle(PRColor.signal)
                }
            }
            .frame(height: 280)

            Text(trendLabel)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(device?.name.isEmpty == false ? device!.name : "Unknown device")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Text("Feel for the pulses in your hand — they speed up as you get closer.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PRColor.background.ignoresSafeArea())
        .onAppear {
            pulse = true
            feedback.prepare()
            scheduleHaptic()
        }
        .onDisappear {
            hapticTimer?.invalidate()
            hapticTimer = nil
        }
        .onChange(of: reading?.percent) { _, _ in
            scheduleHaptic()
        }
    }

    private var pulseDuration: Double {
        max(0.3, HapticPulse.interval(forProximity: reading?.proximity ?? 0))
    }

    private var trendLabel: String {
        switch reading?.trend {
        case .warmer: return "Getting warmer"
        case .colder: return "Getting colder"
        case .steady, .none: return "Searching…"
        }
    }

    private func ringDiameter(for index: Int) -> CGFloat {
        180 + CGFloat(index) * 50
    }

    private func scheduleHaptic() {
        hapticTimer?.invalidate()
        let proximity = reading?.proximity ?? 0
        let interval = HapticPulse.interval(forProximity: proximity)
        hapticTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            feedback.impactOccurred(intensity: hapticImpactIntensity(proximity))
        }
    }

    private func hapticImpactIntensity(_ proximity: Double) -> CGFloat {
        switch HapticPulse.intensity(forProximity: proximity) {
        case .light: return 0.4
        case .medium: return 0.7
        case .heavy: return 1.0
        }
    }
}
