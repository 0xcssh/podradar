import SwiftUI
import UIKit

/// Full-screen hot/cold finder for ONE device — matches PodSpot's paid
/// flow (screen recording reviewed 2026-07-19): device name title, a
/// concentric percentage target, a background that tints from red (far)
/// to green (close) as proximity rises, "Found it!" → Save Location flow,
/// "Cancel" to bail out. Also the mechanic that makes an unidentified
/// ("Unknown device") BLE signal still useful: no need to know what it
/// is, just walk until the pulses speed up and the screen turns green.
struct DeviceFinderView: View {
    let deviceID: String
    @Binding var path: NavigationPath
    @EnvironmentObject private var scanner: BLEScanner
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTimer: Timer?
    @State private var showSaveLocationPrompt = false
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)

    private var device: BLEDevice? {
        scanner.registry.allDevices.first { $0.id == deviceID }
    }

    private var reading: ProximityReading? {
        scanner.proximityByDeviceID[deviceID]
    }

    private var backgroundColor: Color {
        PRColor.proximityBackground(reading?.proximity ?? 0)
    }

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text(device?.displayName ?? "Unknown device")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Move around and follow the signal strength to find your device")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 24)

            Spacer(minLength: 10)

            targetView

            Spacer(minLength: 10)

            VStack(spacing: 16) {
                Button {
                    showSaveLocationPrompt = true
                } label: {
                    Text("Found it!")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(.white, in: Capsule())
                }

                Button("Cancel") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.4), value: reading?.percent)
        .onAppear {
            lightFeedback.prepare()
            mediumFeedback.prepare()
            heavyFeedback.prepare()
            scheduleHaptic()
        }
        .onDisappear {
            hapticTimer?.invalidate()
            hapticTimer = nil
        }
        .onChange(of: reading?.percent) { _, _ in
            scheduleHaptic()
        }
        .alert("Save Location", isPresented: $showSaveLocationPrompt) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") {
                path.append(RadarRoute.saveLocation(deviceID: deviceID, deviceName: device?.displayName ?? "Unknown device"))
            }
        } message: {
            Text("Do you want to save the location of where you found your device? (This makes it easier for you to find your devices next time)")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var targetView: some View {
        ZStack {
            Circle()
                .fill(backgroundColor.lightened(by: 0.18))
                .frame(width: 300, height: 300)
            Circle()
                .fill(backgroundColor.lightened(by: 0.38))
                .frame(width: 230, height: 230)
            Circle()
                .fill(backgroundColor.lightened(by: 0.62))
                .frame(width: 170, height: 170)
            Circle()
                .fill(backgroundColor.lightened(by: 0.92))
                .frame(width: 120, height: 120)
            Text("\(reading?.percent ?? 0)%")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(backgroundColor)
        }
    }

    private func scheduleHaptic() {
        hapticTimer?.invalidate()
        let proximity = reading?.proximity ?? 0
        let interval = HapticPulse.interval(forProximity: proximity)
        hapticTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            generator(forProximity: proximity).impactOccurred(intensity: 1.0)
        }
    }

    private func generator(forProximity proximity: Double) -> UIImpactFeedbackGenerator {
        switch HapticPulse.intensity(forProximity: proximity) {
        case .light: return lightFeedback
        case .medium: return mediumFeedback
        case .heavy: return heavyFeedback
        }
    }
}
