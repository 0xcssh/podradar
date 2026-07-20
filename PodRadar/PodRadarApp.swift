import SwiftUI

@main
struct PodRadarApp: App {
    @StateObject private var scanner = BLEScanner()
    @StateObject private var locationRecorder = LocationRecorder()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var paywallCoordinator: PaywallCoordinator
    @StateObject private var mapFocusCoordinator = MapFocusCoordinator()
    @State private var hasCompletedOnboarding: Bool
    private let deviceStore = DeviceStore()

    init() {
        let store = DeviceStore()
        _paywallCoordinator = StateObject(wrappedValue: PaywallCoordinator(store: store))
        _hasCompletedOnboarding = State(initialValue: store.hasCompletedOnboarding)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootView()
                } else {
                    OnboardingView {
                        deviceStore.hasCompletedOnboarding = true
                        hasCompletedOnboarding = true
                        // The very first paywall gate — see CLAUDE.md's
                        // two-tier paywall plan (2026-07-20): the user
                        // never reaches the free app without seeing this
                        // at least once.
                        paywallCoordinator.requestGate()
                    }
                }
            }
            .environmentObject(scanner)
            .environmentObject(locationRecorder)
            .environmentObject(subscriptionManager)
            .environmentObject(paywallCoordinator)
            .environmentObject(mapFocusCoordinator)
            .preferredColorScheme(.dark)
            .task {
                scanner.restoreIgnoredDeviceIDs(deviceStore.loadIgnoredDeviceIDs())
                scanner.onIgnoredDeviceIDsChanged = { ids in
                    deviceStore.saveIgnoredDeviceIDs(ids)
                }
                scanner.restoreCustomNames(deviceStore.loadCustomNames())
                scanner.onCustomNamesChanged = { names in
                    deviceStore.saveCustomNames(names)
                }
                await subscriptionManager.loadProducts()
                await subscriptionManager.refreshEntitlements()
            }
        }
    }
}
