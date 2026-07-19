import SwiftUI
import UIKit

/// Design system — matches PodSpot's reference flow (screen recordings
/// reviewed 2026-07-19, both free and paid) by explicit request: light
/// blue "Devices" scanning screens, a proximity-driven red→green
/// background on the single-device finder, white cards, dark-on-dark
/// dashboard chrome only on the idle hero screen.
enum PRColor {
    /// Deep tech navy — the idle hero screen only.
    static let navy = Color(hex: "0E1B2C")
    /// Radar-sweep teal — hero screen accent (scan button, hero card).
    static let signal = Color(hex: "2FE6C9")
    /// Warm accent for alerts.
    static let alert = Color(hex: "FF6B5B")
    /// Gold — reserved for the "Unlock Premium" pill.
    static let premium = Color(hex: "D4A93B")
    static let background = Color(hex: "0A1420")
    static let card = Color(hex: "13233A")

    /// Blue used on the "Devices" scanning/list screens (light theme).
    static let devicesBlue = Color(hex: "3E7BFA")
    static let devicesBlueDeep = Color(hex: "2F6FE0")
    /// Light gray→white gradient background for the Devices/Paywall/Save
    /// Location screens.
    static let lightBackgroundTop = Color(hex: "E8E9EC")
    static let lightBackgroundBottom = Color(hex: "FFFFFF")
    static let lightCard = Color(hex: "FFFFFF")
    static let lightText = Color(hex: "1C1C1E")
    static let lightTextSecondary = Color(hex: "6B6B70")
    /// "NEAR" status pill on the Devices list.
    static let nearBadge = Color(hex: "1FD1A6")

    /// Single-device finder screen background: interpolates from this
    /// (far) to `proximityClose` (near) as proximity increases — the
    /// whole screen tints, not just a small indicator.
    static let proximityFar = Color(hex: "C0432B")
    static let proximityClose = Color(hex: "1FA463")

    static func proximityBackground(_ proximity: Double) -> Color {
        Color.mix(proximityFar, proximityClose, t: proximity)
    }
}

extension View {
    func prCard() -> some View {
        self
            .padding(20)
            .background(PRColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    func prPrimaryPill() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(PRColor.signal, in: Capsule())
    }
}

extension Color {
    init(hex: String) {
        let hexValue = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Linear RGB interpolation between two colors, `t` in 0...1.
    static func mix(_ from: Color, _ to: Color, t: Double) -> Color {
        let clamped = min(1, max(0, t))
        let (r1, g1, b1, a1) = from.components
        let (r2, g2, b2, a2) = to.components
        return Color(
            red: r1 + (r2 - r1) * clamped,
            green: g1 + (g2 - g1) * clamped,
            blue: b1 + (b2 - b1) * clamped,
            opacity: a1 + (a2 - a1) * clamped
        )
    }

    /// Blends toward white by `amount` (0 = unchanged, 1 = pure white) —
    /// used to derive the concentric target rings from a single base hue.
    func lightened(by amount: Double) -> Color {
        Color.mix(self, .white, t: amount)
    }

    private var components: (Double, Double, Double, Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
