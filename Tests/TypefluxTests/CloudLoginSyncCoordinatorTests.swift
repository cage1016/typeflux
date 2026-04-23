@testable import Typeflux
import XCTest

@MainActor
final class CloudLoginSyncCoordinatorTests: XCTestCase {
    func testAppliesCloudDefaultsAndNotifiesWhenBothProvidersDiffer() async throws {
        let settingsStore = makeSettingsStore()
        settingsStore.sttProvider = .whisperAPI
        settingsStore.llmProvider = .ollama
        settingsStore.llmRemoteProvider = .openAI

        let notifications = RecordingLocalNotificationService()
        let coordinator = CloudLoginSyncCoordinator(settingsStore: settingsStore, notifications: notifications)

        NotificationCenter.default.post(name: .authDidLogin, object: nil)

        try await waitForNotificationCount(1, in: notifications)

        XCTAssertEqual(settingsStore.sttProvider, .typefluxOfficial)
        XCTAssertEqual(settingsStore.llmProvider, .openAICompatible)
        XCTAssertEqual(settingsStore.llmRemoteProvider, .typefluxCloud)

        let first = await notifications.firstNotification()
        let notification = try XCTUnwrap(first)
        XCTAssertEqual(notification.title, L("cloud.autoSwitch.title"))
        XCTAssertEqual(notification.body, L("cloud.autoSwitch.body"))
        XCTAssertEqual(notification.identifier, CloudLoginSyncCoordinator.notificationIdentifier)
        withExtendedLifetime(coordinator) {}
    }

    func testAppliesCloudDefaultsWhenOnlyOneProviderDiffers() async throws {
        let settingsStore = makeSettingsStore()
        // STT is already Cloud, but LLM is not — should still switch + notify.
        settingsStore.sttProvider = .typefluxOfficial
        settingsStore.llmProvider = .openAICompatible
        settingsStore.llmRemoteProvider = .openAI

        let notifications = RecordingLocalNotificationService()
        let coordinator = CloudLoginSyncCoordinator(settingsStore: settingsStore, notifications: notifications)

        NotificationCenter.default.post(name: .authDidLogin, object: nil)

        try await waitForNotificationCount(1, in: notifications)
        XCTAssertEqual(settingsStore.llmRemoteProvider, .typefluxCloud)
        withExtendedLifetime(coordinator) {}
    }

    func testStaysSilentWhenAlreadyFullyOnCloud() async throws {
        let settingsStore = makeSettingsStore()
        settingsStore.sttProvider = .typefluxOfficial
        settingsStore.llmProvider = .openAICompatible
        settingsStore.llmRemoteProvider = .typefluxCloud

        let notifications = RecordingLocalNotificationService()
        let coordinator = CloudLoginSyncCoordinator(settingsStore: settingsStore, notifications: notifications)

        NotificationCenter.default.post(name: .authDidLogin, object: nil)

        try await Task.sleep(nanoseconds: 150_000_000)

        let count = await notifications.notificationCount()
        XCTAssertEqual(count, 0)
        XCTAssertEqual(settingsStore.sttProvider, .typefluxOfficial)
        XCTAssertEqual(settingsStore.llmProvider, .openAICompatible)
        XCTAssertEqual(settingsStore.llmRemoteProvider, .typefluxCloud)
        withExtendedLifetime(coordinator) {}
    }

    func testIgnoresUnrelatedNotifications() async throws {
        let settingsStore = makeSettingsStore()
        settingsStore.sttProvider = .whisperAPI
        settingsStore.llmProvider = .ollama
        settingsStore.llmRemoteProvider = .openAI

        let notifications = RecordingLocalNotificationService()
        let coordinator = CloudLoginSyncCoordinator(settingsStore: settingsStore, notifications: notifications)

        NotificationCenter.default.post(
            name: Notification.Name("SomeOtherNotification"),
            object: nil,
        )

        try await Task.sleep(nanoseconds: 150_000_000)

        let count = await notifications.notificationCount()
        XCTAssertEqual(count, 0)
        XCTAssertEqual(settingsStore.sttProvider, .whisperAPI)
        XCTAssertEqual(settingsStore.llmProvider, .ollama)
        XCTAssertEqual(settingsStore.llmRemoteProvider, .openAI)
        withExtendedLifetime(coordinator) {}
    }

    // MARK: - Helpers

    private func makeSettingsStore() -> SettingsStore {
        let defaults = UserDefaults(suiteName: "CloudLoginSyncCoordinatorTests.\(UUID().uuidString)")!
        return SettingsStore(defaults: defaults)
    }

    private func waitForNotificationCount(
        _ expectedCount: Int,
        in service: RecordingLocalNotificationService,
    ) async throws {
        for _ in 0 ..< 50 {
            if await service.notificationCount() == expectedCount {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for \(expectedCount) local notification(s)")
    }
}

private actor RecordingLocalNotificationService: LocalNotificationSending {
    struct NotificationRecord {
        let title: String
        let body: String
        let identifier: String
    }

    private(set) var notifications: [NotificationRecord] = []

    func sendLocalNotification(title: String, body: String, identifier: String) async {
        notifications.append(NotificationRecord(title: title, body: body, identifier: identifier))
    }

    func notificationCount() -> Int {
        notifications.count
    }

    func firstNotification() -> NotificationRecord? {
        notifications.first
    }
}
