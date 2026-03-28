import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private let appState: AppStateStore
    private let settingsStore: SettingsStore
    private let historyStore: HistoryStore
    private let onRetryHistory: (HistoryRecord) -> Void

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var cancellables = Set<AnyCancellable>()

    init(
        appState: AppStateStore,
        settingsStore: SettingsStore,
        historyStore: HistoryStore,
        onRetryHistory: @escaping (HistoryRecord) -> Void = { _ in }
    ) {
        self.appState = appState
        self.settingsStore = settingsStore
        self.historyStore = historyStore
        self.onRetryHistory = onRetryHistory
    }

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateTitle()
        rebuildMenu()

        appState.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTitle()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    func stop() {
        menu = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        cancellables.removeAll()
    }

    private func updateTitle() {
        guard let button = statusItem?.button else { return }
        let title: String
        switch appState.status {
        case .idle: title = "VI"
        case .recording: title = "VI●"
        case .processing: title = "VI…"
        case .failed: title = "VI!"
        }
        button.title = title
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let statusItem = NSMenuItem(title: statusMenuTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeItem(title: "Open Voice Studio", action: #selector(openHome)))
        menu.addItem(makeItem(title: "History…", action: #selector(openHistory)))
        menu.addItem(makeItem(title: "Personas", action: #selector(openPersonas)))
        menu.addItem(NSMenuItem.separator())

        let appearanceItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        appearanceItem.submenu = buildAppearanceMenu()
        menu.addItem(appearanceItem)

        let settingsItem = makeItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())

        let versionItem = NSMenuItem(title: versionMenuTitle, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeItem(title: "Quit VoiceInput", action: #selector(quit), keyEquivalent: "q"))

        self.menu = menu
        statusItem?.menu = menu
    }

    private func buildAppearanceMenu() -> NSMenu {
        let menu = NSMenu(title: "Appearance")

        menu.addItem(makeAppearanceItem(mode: .system))
        menu.addItem(makeAppearanceItem(mode: .light))
        menu.addItem(makeAppearanceItem(mode: .dark))

        return menu
    }

    private func makeAppearanceItem(mode: AppearanceMode) -> NSMenuItem {
        let item = NSMenuItem(title: mode.displayName, action: #selector(selectAppearanceMode(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = mode.rawValue
        item.state = settingsStore.appearanceMode == mode ? .on : .off
        return item
    }

    private func makeItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private var statusMenuTitle: String {
        switch appState.status {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording in progress…"
        case .processing:
            return "Processing latest capture…"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    private var versionMenuTitle: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        switch (version, bundleVersion) {
        case let (version?, bundleVersion?) where version != bundleVersion:
            return "Version \(version) (\(bundleVersion))"
        case let (version?, _):
            return "Version \(version)"
        case let (_, bundleVersion?):
            return "Build \(bundleVersion)"
        default:
            return "VoiceInput"
        }
    }

    private func openStudio(_ section: StudioSection) {
        switch section {
        case .history:
            openHistory()
        case .settings:
            openSettings()
        default:
            SettingsWindowController.shared.show(
                settingsStore: settingsStore,
                historyStore: historyStore,
                initialSection: section,
                onRetryHistory: onRetryHistory
            )
        }
    }

    @objc private func openHome() {
        openStudio(.home)
    }

    @objc private func openPersonas() {
        openStudio(.personas)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .settings,
            onRetryHistory: onRetryHistory
        )
    }

    @objc private func openHistory() {
        SettingsWindowController.shared.show(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .history,
            onRetryHistory: onRetryHistory
        )
    }

    @objc private func selectAppearanceMode(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let mode = AppearanceMode(rawValue: rawValue)
        else {
            return
        }

        settingsStore.appearanceMode = mode
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
