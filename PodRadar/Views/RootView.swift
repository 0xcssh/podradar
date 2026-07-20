import SwiftUI

/// M0 placeholder tab shell. Onboarding + paywall gating land at M3/M4
/// (see SPEC.md) — for now this proves the pipeline (CI build → device
/// install) end to end before any real feature work.
private enum RootTab: Hashable {
    case radar, map, settings
}

struct RootView: View {
    @EnvironmentObject private var scanner: BLEScanner
    @EnvironmentObject private var mapFocusCoordinator: MapFocusCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: RootTab = .radar

    var body: some View {
        TabView(selection: $selectedTab) {
            RadarView()
                .tabItem { Label("Radar", systemImage: "dot.radiowaves.left.and.right") }
                .tag(RootTab.radar)

            MapView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(RootTab.map)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .tint(PRColor.signal)
        // PreviousLocationsView (nested inside the Radar tab's own
        // NavigationStack) sets this to jump straight to that device's pin
        // on the Map tab instead of just describing where it was.
        .onChange(of: mapFocusCoordinator.deviceID) { _, deviceID in
            if deviceID != nil { selectedTab = .map }
        }
        // Scanning lives at the app-shell level, not per-tab/per-screen:
        // tying it to RadarView's onAppear/onDisappear used to stop the
        // scan the moment a NavigationLink pushed DeviceFinderView (a
        // pushed destination makes SwiftUI fire onDisappear on the
        // screen underneath it), freezing every reading — field-reported
        // 2026-07-17. Bluetooth LE scanning is cheap enough to just run
        // for the whole foreground session.
        .onAppear { scanner.startScanning() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: scanner.startScanning()
            case .background: scanner.stopScanning()
            case .inactive: break
            @unknown default: break
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(BLEScanner())
        .environmentObject(LocationRecorder())
        .environmentObject(SubscriptionManager())
        .environmentObject(PaywallCoordinator(store: DeviceStore()))
        .environmentObject(MapFocusCoordinator())
}
