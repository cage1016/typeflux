import AppKit
import SwiftUI

@MainActor
final class LoginWindowController: NSObject {
    static let shared = LoginWindowController()

    private var window: NSWindow?
    private var hostingView: NSHostingView<LoginView>?
    private var appearanceObserver: NSObjectProtocol?
    private let settingsStore = SettingsStore()

    override init() {
        super.init()
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: .appearanceModeDidChange,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, let window = self.window else { return }
                window.appearance = AppAppearance.nsAppearance(for: self.settingsStore.appearanceMode)
            }
        }
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let loginView = LoginView { [weak self] in
            self?.window?.close()
        }
        let hosting = NSHostingView(rootView: loginView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false,
        )
        window.title = L("auth.login.windowTitle")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(StudioTheme.windowBackground)
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.minSize = NSSize(width: 400, height: 480)
        window.maxSize = NSSize(width: 500, height: 700)
        window.appearance = AppAppearance.nsAppearance(for: settingsStore.appearanceMode)

        hostingView = hosting
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension LoginWindowController: NSWindowDelegate {
    func windowWillClose(_: Notification) {
        window = nil
        hostingView = nil
    }
}
