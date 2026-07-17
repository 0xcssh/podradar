import SwiftUI

struct RadarView: View {
    @EnvironmentObject private var scanner: BLEScanner

    var body: some View {
        NavigationStack {
            Group {
                if scanner.registry.inRangeDevices(asOf: .now).isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(scanner.registry.inRangeDevices(asOf: .now)) { device in
                            DeviceRow(device: device, reading: scanner.proximityByDeviceID[device.id])
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
            .navigationTitle("PodRadar")
            .toolbarBackground(PRColor.background, for: .navigationBar)
            .onAppear { scanner.startScanning() }
            .onDisappear { scanner.stopScanning() }
        }
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
