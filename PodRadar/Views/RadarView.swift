import CoreBluetooth
import SwiftUI
import UIKit

struct RadarView: View {
    @EnvironmentObject private var scanner: BLEScanner
    /// The scan itself always runs (RootView owns that lifecycle) — this
    /// only gates which UI is shown, matching PodSpot's hero-screen-first
    /// pattern (reference screenshot reviewed 2026-07-17) rather than
    /// dumping a live list on the user immediately.
    @State private var hasTappedScan = false

    var body: some View {
        NavigationStack {
            Group {
                if let message = bluetoothProblemMessage {
                    bluetoothProblemState(message)
                } else if !hasTappedScan {
                    HeroScanView(onTapScan: { hasTappedScan = true })
                } else if scanner.registry.inRangeDevices(asOf: .now).isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(scanner.registry.inRangeDevices(asOf: .now)) { device in
                            NavigationLink {
                                DeviceFinderView(deviceID: device.id)
                            } label: {
                                DeviceRow(device: device, reading: scanner.proximityByDeviceID[device.id])
                            }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        scanner.ignore(id: device.id)
                                    } label: {
                                        Label("Ignore", systemImage: "eye.slash")
                                    }
                                    Button {
                                        scanner.toggleFavorite(id: device.id)
                                    } label: {
                                        Label(
                                            device.isFavorite ? "Unfavorite" : "Favorite",
                                            systemImage: device.isFavorite ? "star.slash" : "star"
                                        )
                                    }
                                    .tint(PRColor.signal)
                                }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }
            }
            .background(PRColor.background.ignoresSafeArea())
            .navigationTitle(hasTappedScan ? "PodRadar" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PRColor.background, for: .navigationBar)
            .toolbar {
                if hasTappedScan {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            hasTappedScan = false
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    /// nil when Bluetooth is usable (poweredOn) or we don't know yet
    /// (`.unknown`/`.resetting` — CBCentralManager settles quickly after
    /// launch, no need to alarm the user over that transient state).
    private var bluetoothProblemMessage: String? {
        switch scanner.bluetoothState {
        case .poweredOff: return "Turn on Bluetooth to start scanning for devices."
        case .unauthorized: return "PodRadar needs Bluetooth access. Enable it in Settings."
        case .unsupported: return "This device doesn't support Bluetooth Low Energy."
        case .poweredOn, .unknown, .resetting: return nil
        @unknown default: return nil
        }
    }

    private func bluetoothProblemState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.6))
            Text(message)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if scanner.bluetoothState == .unauthorized {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .prPrimaryPill()
                .padding(.horizontal, 60)
            }
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
        .background(PRColor.background.ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(PRColor.signal)
            Text("Scanning for nearby devices…")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Make sure your headphones are powered on and nearby.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
        .background(PRColor.background.ignoresSafeArea())
    }
}

/// Idle home screen shown before the user commits to looking at results —
/// reproduces PodSpot's actual home screen (screenshot reviewed
/// 2026-07-17): wordmark, "Tap to Scan" hook, a big circular tap target,
/// and a shortcut into previously-recorded locations — adapted to
/// PodRadar's navy/teal identity instead of PodSpot's blue/gold.
private struct HeroScanView: View {
    let onTapScan: () -> Void
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 20)

            VStack(spacing: 6) {
                Text("PodRadar")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("BLUETOOTH DEVICE FINDER")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text("Tap to Scan")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Search for AirPods & other Bluetooth devices around you")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            NavigationLink {
                PaywallPlaceholderView()
            } label: {
                Label("Unlock Premium", systemImage: "star.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(PRColor.premium, in: Capsule())
            }

            Spacer(minLength: 10)

            Button(action: onTapScan) {
                ZStack {
                    Circle()
                        .fill(PRColor.signal.opacity(0.15))
                        .frame(width: 220, height: 220)
                    Circle()
                        .fill(PRColor.card)
                        .frame(width: 180, height: 180)
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(PRColor.signal)
                }
                .scaleEffect(isPressed ? 0.94 : 1)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )

            Spacer(minLength: 10)

            NavigationLink {
                PreviousLocationsView()
            } label: {
                Label("Previous Locations", systemImage: "person.crop.square")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PRColor.card, in: Capsule())
            }
            .padding(.horizontal, 40)

            Spacer(minLength: 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PRColor.background.ignoresSafeArea())
    }
}

private struct DeviceRow: View {
    let device: BLEDevice
    let reading: ProximityReading?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: device.kind.symbolName)
                .font(.title2)
                .foregroundStyle(PRColor.signal)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name.isEmpty ? "Unknown device" : device.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                if let reading {
                    Text(trendLabel(reading.trend))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer()
            if device.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(PRColor.signal)
            }
            if let reading {
                Text("\(reading.percent)%")
                    .font(.title2.bold())
                    .foregroundStyle(PRColor.signal)
            }
        }
        .prCard()
    }

    private func trendLabel(_ trend: ProximityTrend) -> String {
        switch trend {
        case .warmer: return "Getting closer"
        case .colder: return "Getting farther"
        case .steady: return "Steady"
        }
    }
}

private extension DeviceKind {
    var symbolName: String {
        switch self {
        case .headphones: return "headphones"
        case .earbuds: return "airpods"
        case .watch: return "applewatch"
        case .tracker: return "location.circle"
        case .speaker: return "hifispeaker"
        case .unknown: return "dot.radiowaves.left.and.right"
        }
    }
}
