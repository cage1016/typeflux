import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let appState: AppStateStore
    private let settingsStore: SettingsStore
    private let historyStore: HistoryStore
    private let onRetryHistory: (HistoryRecord) -> Void

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var menuViewModel: StatusBarMenuViewModel?
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

        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menuViewModel = StatusBarMenuViewModel(
            status: appState.status,
            appearanceMode: settingsStore.appearanceMode,
            settingsStore: settingsStore,
            openSection: { [weak self] section in
                self?.openStudio(section)
            },
            quitAction: { [weak self] in
                self?.quit()
            }
        )
        self.menuViewModel = menuViewModel

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 550, height: 340)
        popover.contentViewController = NSHostingController(
            rootView: StatusBarMenuPopoverView(
                viewModel: menuViewModel,
                dismiss: { [weak self] in
                    self?.popover?.performClose(nil)
                }
            )
        )
        self.popover = popover

        appState.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTitle()
                self?.menuViewModel?.status = self?.appState.status ?? .idle
            }
            .store(in: &cancellables)
    }

    func stop() {
        popover?.performClose(nil)
        popover = nil
        menuViewModel = nil
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

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        menuViewModel?.appearanceMode = settingsStore.appearanceMode
        menuViewModel?.status = appState.status
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
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

    private func openSettings() {
        SettingsWindowController.shared.show(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .settings,
            onRetryHistory: onRetryHistory
        )
    }

    private func openHistory() {
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
