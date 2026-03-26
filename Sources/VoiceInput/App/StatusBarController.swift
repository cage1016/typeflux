import AppKit
import Combine
import SwiftUI

final class StatusBarController: NSObject {
    private let appState: AppStateStore
    private let settingsStore: SettingsStore
    private let historyStore: HistoryStore
    private let onRetryHistory: (HistoryRecord) -> Void

    private var statusItem: NSStatusItem?
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

        let menu = NSMenu()
        menu.autoenablesItems = false

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let historyItem = NSMenuItem(title: "History…", action: #selector(openHistory), keyEquivalent: "h")
        historyItem.target = self
        menu.addItem(historyItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem?.menu = menu

        appState.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTitle()
            }
            .store(in: &cancellables)
    }

    func stop() {
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

    @MainActor
    @objc private func openSettings() {
        SettingsWindowController.shared.show(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .settings,
            onRetryHistory: onRetryHistory
        )
    }

    @MainActor
    @objc private func openHistory() {
        SettingsWindowController.shared.show(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .history,
            onRetryHistory: onRetryHistory
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
