import Foundation
import os

extension Notification.Name {
    /// Posted after account-backed Typeflux Cloud model defaults have been
    /// applied to ``SettingsStore``.
    static let cloudAccountModelDefaultsDidApply = Notification.Name(
        "CloudLoginSyncCoordinator.cloudAccountModelDefaultsDidApply",
    )
}

/// Switches STT and LLM selections to the Typeflux Cloud providers after a
/// successful explicit login, and notifies the user about the change.
///
/// Listens for `.authDidLogin` (posted by ``AuthState/handleLoginSuccess(token:expiresAt:refreshToken:)``)
/// and is intentionally silent when both providers already point at Cloud so
/// users who routinely sign back in are not pestered.
@MainActor
final class CloudLoginSyncCoordinator {
    static let notificationIdentifier = "ai.gulu.app.typeflux.cloud-auto-switch"

    private let settingsStore: SettingsStore
    private let notifications: LocalNotificationSending
    private let logger = Logger(subsystem: "ai.gulu.app.typeflux", category: "CloudLoginSyncCoordinator")
    private var observer: NSObjectProtocol?

    init(settingsStore: SettingsStore, notifications: LocalNotificationSending) {
        self.settingsStore = settingsStore
        self.notifications = notifications
        observer = NotificationCenter.default.addObserver(
            forName: .authDidLogin,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyCloudDefaults()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Exposed for tests; in production triggered only via `.authDidLogin`.
    func applyCloudDefaults() {
        let alreadySTTCloud = settingsStore.sttProvider == .typefluxOfficial
        let alreadyLLMCloud = settingsStore.llmProvider == .openAICompatible
            && settingsStore.llmRemoteProvider == .typefluxCloud

        guard !(alreadySTTCloud && alreadyLLMCloud) else {
            logger.debug("Cloud providers already selected; skipping auto-switch notification")
            return
        }

        settingsStore.sttProvider = .typefluxOfficial
        settingsStore.llmProvider = .openAICompatible
        settingsStore.llmRemoteProvider = .typefluxCloud
        settingsStore.applyDefaultPersonaIfLLMConfigured()
        NotificationCenter.default.post(name: .cloudAccountModelDefaultsDidApply, object: settingsStore)

        let title = L("cloud.autoSwitch.title")
        let body = L("cloud.autoSwitch.body")
        let identifier = Self.notificationIdentifier
        let sender = notifications
        Task {
            await sender.sendLocalNotification(
                title: title,
                body: body,
                identifier: identifier,
            )
        }
    }
}
