import SwiftUI

/// M0 placeholder tab shell. Onboarding + paywall gating land at M3/M4
/// (see SPEC.md) — for now this proves the pipeline (CI build → device
/// install) end to end before any real feature work.
struct RootView: View {
    var body: some View {
        TabView {
            RadarView()
                .tabItem { Label("Radar", systemImage: "dot.radiowaves.left.and.right") }

            MapView()
                .tabItem { Label("Map", systemImage: "map") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(PRColor.signal)
    }
}

#Preview {
    RootView()
        .environmentObject(BLEScanner())
        .environmentObject(LocationRecorder())
        .environmentObject(SubscriptionManager())
}
