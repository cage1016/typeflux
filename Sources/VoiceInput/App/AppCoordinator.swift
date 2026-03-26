import AppKit

final class AppCoordinator {
    private let di = DIContainer()

    private var statusBarController: StatusBarController?
    private var workflowController: WorkflowController?

    func start() {
        let workflowController = WorkflowController(
            appState: di.appState,
            settingsStore: di.settingsStore,
            hotkeyService: di.hotkeyService,
            audioRecorder: di.audioRecorder,
            sttRouter: di.sttRouter,
            llmService: di.llmService,
            textInjector: di.textInjector,
            clipboard: di.clipboard,
            historyStore: di.historyStore,
            overlayController: di.overlayController
        )
        self.workflowController = workflowController

        statusBarController = StatusBarController(
            appState: di.appState,
            settingsStore: di.settingsStore,
            historyStore: di.historyStore,
            onRetryHistory: { [weak workflowController] record in
                workflowController?.retry(record: record)
            }
        )
        statusBarController?.start()
        self.workflowController?.start()
    }

    func stop() {
        workflowController?.stop()
        statusBarController?.stop()
    }
}
