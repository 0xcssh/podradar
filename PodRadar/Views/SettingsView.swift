import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Subscription")
                        Spacer()
                        Text(subscriptionManager.isSubscribed ? "Pro" : "Free")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
