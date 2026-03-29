import AppKit
import SwiftUI

@MainActor
final class AboutWindowController: NSObject {
    static let shared = AboutWindowController()

    private let settingsStore = SettingsStore()
    private var window: NSWindow?
    private var hostingView: NSHostingView<AboutView>?
    private var languageObserver: NSObjectProtocol?

    override init() {
        super.init()
        languageObserver = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, let window = self.window else { return }
                self.hostingView?.rootView = AboutView(appearanceMode: self.settingsStore.appearanceMode)
                window.title = L("window.about")
            }
        }
    }

    func show() {
        AppLocalization.shared.setLanguage(settingsStore.appLanguage)
        let rootView = AboutView(appearanceMode: settingsStore.appearanceMode)

        if let window {
            hostingView?.rootView = rootView
            applyAppearance(to: window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L("window.about")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(StudioTheme.windowBackground)
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.minSize = NSSize(width: 480, height: 560)
        applyAppearance(to: window)

        self.hostingView = hosting
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyAppearance(to window: NSWindow) {
        switch settingsStore.appearanceMode {
        case .system:
            window.appearance = nil
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

extension AboutWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
        hostingView = nil
    }
}
