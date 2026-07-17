import SwiftUI

struct RadarView: View {
    @EnvironmentObject private var scanner: BLEScanner

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if scanner.registry.inRangeDevices(asOf: .now).isEmpty {
                        emptyState
                    } else {
                        ForEach(scanner.registry.inRangeDevices(asOf: .now)) { device in
                            DeviceRow(device: device, reading: scanner.proximityByDeviceID[device.id])
                        }
                    }
                }
                .padding()
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
    }
}

private struct DeviceRow: View {
    let device: BLEDevice
    let reading: ProximityReading?

    var body: some View {
        HStack {
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
