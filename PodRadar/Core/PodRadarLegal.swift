import Foundation

/// Legal pages, hosted the same way as RepLock/Loopa: a standalone public
/// repo (0xcssh/podradar-legal) served via GitHub Pages — no backend
/// needed. Apple requires functional links to both on any subscription
/// screen (Guideline 3.1.2).
enum PodRadarLegal {
    static let privacyURL = URL(string: "https://0xcssh.github.io/podradar-legal/privacy.html")!
    static let termsURL = URL(string: "https://0xcssh.github.io/podradar-legal/terms.html")!
    static let supportEmailURL = URL(string: "mailto:awdianthony@gmail.com?subject=PodRadar")!
}
