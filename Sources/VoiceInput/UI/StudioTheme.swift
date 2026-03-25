import AppKit
import SwiftUI

enum StudioTheme {
    enum Layout {
        static let sidebarWidth: CGFloat = 208
        static let contentMaxWidth: CGFloat = 920
        static let contentInset: CGFloat = 32
        static let settingsWindowWidth: CGFloat = 1220
        static let settingsWindowHeight: CGFloat = 780
        static let settingsWindowMinWidth: CGFloat = 1080
        static let settingsWindowMinHeight: CGFloat = 700
        static let overlayWidth: CGFloat = 320
        static let overlayHeight: CGFloat = 92
        static let historyWindowWidth: CGFloat = 680
        static let historyWindowHeight: CGFloat = 520
        static let floatingActionButtonSize: CGFloat = 54
        static let iconBadgeSize: CGFloat = 52
        static let compactIconBadgeSize: CGFloat = 34
        static let metricMinHeight: CGFloat = 184
        static let actionCardMinHeight: CGFloat = 210
        static let modelCardMinHeight: CGFloat = 240
        static let textEditorMinHeight: CGFloat = 360
    }

    enum Spacing {
        static let xxxSmall: CGFloat = 4
        static let xxSmall: CGFloat = 6
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 10
        static let smallMedium: CGFloat = 12
        static let medium: CGFloat = 14
        static let mediumLarge: CGFloat = 16
        static let large: CGFloat = 18
        static let xLarge: CGFloat = 20
        static let xxLarge: CGFloat = 22
        static let xxxLarge: CGFloat = 24
        static let section: CGFloat = 28
    }

    enum CornerRadius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 14
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 18
        static let xxLarge: CGFloat = 20
        static let hero: CGFloat = 22
        static let capsule: CGFloat = 999
    }

    enum BorderWidth {
        static let thin: CGFloat = 1
        static let emphasis: CGFloat = 1.5
    }

    enum Shadow {
        static let cardRadius: CGFloat = 12
        static let cardY: CGFloat = 6
        static let floatingRadius: CGFloat = 18
        static let floatingY: CGFloat = 10
    }

    enum Typography {
        static let sidebarTitle: CGFloat = 16
        static let sidebarEyebrow: CGFloat = 9
        static let heroEyebrow: CGFloat = 11
        static let heroTitle: CGFloat = 36
        static let heroMetric: CGFloat = 40
        static let pageTitle: CGFloat = 28
        static let sectionTitle: CGFloat = 24
        static let subsectionTitle: CGFloat = 20
        static let cardTitle: CGFloat = 18
        static let settingTitle: CGFloat = 17
        static let bodyLarge: CGFloat = 15
        static let body: CGFloat = 14
        static let bodySmall: CGFloat = 13
        static let caption: CGFloat = 12
        static let eyebrow: CGFloat = 10
    }

    static let sidebarWidth = Layout.sidebarWidth
    static let contentMaxWidth = Layout.contentMaxWidth
    static let contentInset = Layout.contentInset

    static let accent = dynamic(light: NSColor(calibratedRed: 0.08, green: 0.39, blue: 0.86, alpha: 1), dark: NSColor(calibratedRed: 0.34, green: 0.62, blue: 1.0, alpha: 1))
    static let accentSoft = dynamic(light: NSColor(calibratedRed: 0.92, green: 0.95, blue: 1.0, alpha: 1), dark: NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.33, alpha: 1))
    static let background = dynamic(light: NSColor(calibratedRed: 0.978, green: 0.982, blue: 0.992, alpha: 1), dark: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.13, alpha: 1))
    static let sidebar = dynamic(light: NSColor(calibratedRed: 0.978, green: 0.982, blue: 0.992, alpha: 1), dark: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.13, alpha: 1))
    static let surface = dynamic(light: NSColor(calibratedRed: 0.985, green: 0.985, blue: 0.995, alpha: 1), dark: NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.20, alpha: 1))
    static let surfaceMuted = dynamic(light: NSColor(calibratedRed: 0.955, green: 0.96, blue: 0.975, alpha: 1), dark: NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.23, alpha: 1))
    static let border = dynamic(light: NSColor(calibratedRed: 0.89, green: 0.90, blue: 0.94, alpha: 1), dark: NSColor(calibratedWhite: 0.25, alpha: 1))
    static let textPrimary = dynamic(light: NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 1), dark: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1))
    static let textSecondary = dynamic(light: NSColor(calibratedRed: 0.44, green: 0.47, blue: 0.55, alpha: 1), dark: NSColor(calibratedRed: 0.66, green: 0.69, blue: 0.76, alpha: 1))
    static let success = dynamic(light: NSColor(calibratedRed: 0.12, green: 0.67, blue: 0.39, alpha: 1), dark: NSColor(calibratedRed: 0.31, green: 0.84, blue: 0.56, alpha: 1))
    static let warning = dynamic(light: NSColor(calibratedRed: 0.93, green: 0.55, blue: 0.16, alpha: 1), dark: NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.29, alpha: 1))
    static let danger = dynamic(light: NSColor(calibratedRed: 0.85, green: 0.22, blue: 0.22, alpha: 1), dark: NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.43, alpha: 1))

    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            }
        )
    }
}

extension Font {
    static func studioDisplay(_ size: CGFloat, weight: Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }

    static func studioBody(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func studioMono(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
