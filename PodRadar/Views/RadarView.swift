import CoreBluetooth
import SwiftUI
import UIKit

struct RadarView: View {
    @EnvironmentObject private var scanner: BLEScanner
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    /// The scan itself always runs (RootView owns that lifecycle) — this
    /// only gates which UI is shown, matching PodSpot's hero-screen-first
    /// pattern (reference screenshot reviewed 2026-07-17) rather than
    /// dumping a live list on the user immediately.
    @State private var hasTappedScan = false
    @State private var path = NavigationPath()
    @State private var showPaywall = false
    @State private var renamingDeviceID: String?
    @State private var renameText = ""

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let message = bluetoothProblemMessage {
                    bluetoothProblemState(message)
                } else if !hasTappedScan {
                    HeroScanView(onTapScan: { hasTappedScan = true })
                } else {
                    devicesListScreen
                }
            }
            .navigationDestination(for: RadarRoute.self) { route in
                switch route {
                case .finder(let deviceID):
                    DeviceFinderView(deviceID: deviceID, path: $path)
                case .saveLocation(let deviceID, let deviceName):
                    SaveLocationView(deviceID: deviceID, deviceName: deviceName, path: $path)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Rename Device", isPresented: renameAlertBinding) {
            TextField("Device name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let id = renamingDeviceID {
                    scanner.rename(id: id, to: renameText)
                }
            }
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(get: { renamingDeviceID != nil }, set: { if !$0 { renamingDeviceID = nil } })
    }

    /// "Devices" screen: matches PodSpot's list (screen recording reviewed
    /// 2026-07-19) — light background, white cards, a generic "NEAR" pill
    /// (not a live percentage — that precision is the paid feature, shown
    /// only once a device is tapped and opens DeviceFinderView).
    private var devicesListScreen: some View {
        ZStack {
            LinearGradient(
                colors: [PRColor.lightBackgroundTop, PRColor.lightBackgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if scanner.registry.inRangeDevices(asOf: .now).isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    Text("Tap on your device to track down its precise location")
                        .font(.subheadline)
                        .foregroundStyle(PRColor.lightTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    List {
                        ForEach(scanner.registry.inRangeDevices(asOf: .now)) { device in
                            Button {
                                openDevice(device)
                            } label: {
                                DevicesListRow(device: device)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
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
                                .tint(PRColor.devicesBlue)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    renameText = device.customName ?? ""
                                    renamingDeviceID = device.id
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(PRColor.devicesBlue)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)

                    Text("Can't see your device?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PRColor.lightText)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.06), in: Capsule())
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    hasTappedScan = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(PRColor.lightText)
                }
            }
        }
    }

    private func openDevice(_ device: BLEDevice) {
        if subscriptionManager.isSubscribed {
            path.append(RadarRoute.finder(deviceID: device.id))
        } else {
            showPaywall = true
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
                .foregroundStyle(PRColor.devicesBlue)
            Text("Scanning for nearby devices…")
                .font(.headline)
                .foregroundStyle(PRColor.lightText)
            Text("Make sure your headphones are powered on and nearby.")
                .font(.subheadline)
                .foregroundStyle(PRColor.lightTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
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
                PaywallView()
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

private struct DevicesListRow: View {
    let device: BLEDevice

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: device.kind.symbolName)
                .font(.title3)
                .foregroundStyle(PRColor.lightTextSecondary)
                .frame(width: 28)

            Text(device.displayName)
                .font(.body.weight(.medium))
                .foregroundStyle(PRColor.lightText)

            if device.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(PRColor.premium)
            }

            Spacer()

            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(PRColor.devicesBlue)
            Text("NEAR")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(PRColor.nearBadge, in: Capsule())
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(PRColor.lightCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
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
