import AppKit

enum AppAppearance {
    static func nsAppearance(for mode: AppearanceMode) -> NSAppearance? {
        switch mode {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    @MainActor
    static func apply(_ mode: AppearanceMode) {
        NSApp.appearance = nsAppearance(for: mode)
    }
}
