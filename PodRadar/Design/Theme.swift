import SwiftUI

/// Design system placeholder — swap for real brand artwork before
/// submission (RepLock's "never look cheap" rule: no emojis, SF Symbols
/// only, editorial-quality imagery once art lands).
enum PRColor {
    /// Deep tech navy — structure, chrome, headers.
    static let navy = Color(hex: "0E1B2C")
    /// Radar-sweep teal — the "signal found" accent. Reserve for proximity
    /// feedback (radar sweep, hot/cold indicator, CTA), don't dilute it.
    static let signal = Color(hex: "2FE6C9")
    /// Warm accent for the paywall / reward moments only.
    static let alert = Color(hex: "FF6B5B")
    static let background = Color(hex: "0A1420")
    static let card = Color(hex: "13233A")
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
}
