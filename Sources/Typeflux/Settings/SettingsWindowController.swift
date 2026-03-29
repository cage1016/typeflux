import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var viewModel: StudioViewModel?
    private var languageObserver: NSObjectProtocol?

    override init() {
        super.init()
        languageObserver = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.window?.title = L("window.voiceStudio")
            }
        }
    }

    func show(
        settingsStore: SettingsStore,
        historyStore: HistoryStore,
        initialSection: StudioSection = .settings,
        onRetryHistory: @escaping (HistoryRecord) -> Void = { _ in }
    ) {
        if let window {
            viewModel?.navigate(to: initialSection)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: initialSection,
            onRetryHistory: onRetryHistory
        )
        AppLocalization.shared.setLanguage(viewModel.appLanguage)
        let view = StudioView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: StudioTheme.Layout.settingsWindowWidth,
                height: StudioTheme.Layout.settingsWindowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L("window.voiceStudio")
        window.center()
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(StudioTheme.windowBackground)
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.minSize = NSSize(
            width: StudioTheme.Layout.settingsWindowMinWidth,
            height: StudioTheme.Layout.settingsWindowMinHeight
        )

        self.viewModel = viewModel
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
        viewModel = nil
    }
}
