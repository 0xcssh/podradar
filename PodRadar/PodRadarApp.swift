import SwiftUI

@main
struct PodRadarApp: App {
    @StateObject private var scanner = BLEScanner()
    @StateObject private var locationRecorder = LocationRecorder()
    @StateObject private var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(scanner)
                .environmentObject(locationRecorder)
                .environmentObject(subscriptionManager)
                .preferredColorScheme(.dark)
                .task {
                    scanner.onDeviceWentStale = { device in
                        guard let location = locationRecorder.currentLocationSnapshot() else { return }
                        scanner.registry.attachLastKnownLocation(location, toDeviceID: device.id)
                    }
                    await subscriptionManager.loadProducts()
                    await subscriptionManager.refreshEntitlements()
                }
        }
    }
}
