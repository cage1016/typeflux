import AppKit
import Combine
import SwiftUI

final class StatusBarController: NSObject {
    private let appState: AppStateStore
    private let settingsStore: SettingsStore

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppStateStore, settingsStore: SettingsStore) {
        self.appState = appState
        self.settingsStore = settingsStore
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

    @objc private func openSettings() {
        SettingsWindowController.shared.show(settingsStore: settingsStore)
    }

    @objc private func openHistory() {
        HistoryWindowController.shared.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
