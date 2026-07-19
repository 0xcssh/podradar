import SwiftUI

@main
struct PodRadarApp: App {
    @StateObject private var scanner = BLEScanner()
    @StateObject private var locationRecorder = LocationRecorder()
    @StateObject private var subscriptionManager = SubscriptionManager()
    private let deviceStore = DeviceStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(scanner)
                .environmentObject(locationRecorder)
                .environmentObject(subscriptionManager)
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
                    scanner.onDeviceWentStale = { device in
                        guard let location = locationRecorder.currentLocationSnapshot() else { return }
                        scanner.attachLastKnownLocation(location, toDeviceID: device.id)
                    }
                    await subscriptionManager.loadProducts()
                    await subscriptionManager.refreshEntitlements()
                }
        }
    }
}
