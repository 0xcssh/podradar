import SwiftUI

/// "Can't see your device?" troubleshooting sheet — matches PodSpot's
/// reference exactly (screenshot reviewed 2026-07-19): four tips covering
/// the real, inherent limits of passive BLE scanning (Find My protocol is
/// private to Apple, devices must be on/in range/charged). Presented from
/// the Devices list's bottom button, which previously did nothing.
struct CantSeeDeviceView: View {
    @Environment(\.dismiss) private var dismiss

    // SwiftUI only auto-localizes Text(_:) given a STRING LITERAL directly;
    // a String variable (like these array elements) takes the verbatim
    // overload instead. String(localized:) does the catalog lookup
    // explicitly — see RepLock/Loopa's documented convention.
    private let tips: [(icon: String, text: String)] = [
        ("case.fill", String(localized: "If you are looking for AirPods, make sure the AirPods are not in a case")),
        ("power", String(localized: "The Bluetooth device must be turned on in order to be detected")),
        ("battery.25", String(localized: "The device must still have some battery left")),
        ("antenna.radiowaves.left.and.right", String(localized: "Make sure the device is within Bluetooth signal range"))
    ]

    var body: some View {
        VStack(spacing: 28) {
            Capsule()
                .fill(Color.black.opacity(0.15))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            Text("Can't see your device?")
                .font(.title2.bold())
                .foregroundStyle(PRColor.lightText)

            VStack(alignment: .leading, spacing: 22) {
                ForEach(tips, id: \.text) { tip in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: tip.icon)
                            .font(.title3)
                            .foregroundStyle(PRColor.devicesBlue)
                            .frame(width: 28)
                        Text(tip.text)
                            .font(.subheadline)
                            .foregroundStyle(PRColor.lightText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)

            Spacer(minLength: 0)
        }
        // maxHeight: .infinity (not just maxWidth) so the background below
        // stretches across the FULL sheet frame, not just the intrinsic
        // height of the content — otherwise the gradient stops short of
        // the sheet's actual bounds and the system's black chrome shows
        // through as bars above/below (field-reported 2026-07-20).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [PRColor.lightBackgroundTop, PRColor.lightBackgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        // Field-reported 2026-07-19: .medium left a large empty gap below
        // the 4 tips — the content is a fixed, short height that doesn't
        // need half the screen. .height sizes the sheet to fit instead.
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.hidden)
    }
}
