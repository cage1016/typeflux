@testable import Typeflux
import XCTest

@MainActor
final class SettingsViewModelCloudDefaultsTests: XCTestCase {
    func testCloudDefaultsNotificationSyncsModelSelectionState() async throws {
        let suiteName = "SettingsViewModelCloudDefaultsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.sttProvider = .localModel
        settingsStore.llmProvider = .openAICompatible
        settingsStore.llmRemoteProvider = .openAI

        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: EmptyHistoryStore(),
            initialSection: .models,
            modelManager: NoopOllamaModelManager(),
            localModelManager: NoopLocalSTTModelManager(),
        )
        viewModel.setModelDomain(.llm)

        settingsStore.sttProvider = .typefluxOfficial
        settingsStore.llmProvider = .openAICompatible
        settingsStore.llmRemoteProvider = .typefluxCloud
        NotificationCenter.default.post(name: .cloudAccountModelDefaultsDidApply, object: settingsStore)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.sttProvider, .typefluxOfficial)
        XCTAssertEqual(viewModel.llmProvider, .openAICompatible)
        XCTAssertEqual(viewModel.llmRemoteProvider, .typefluxCloud)
        XCTAssertEqual(viewModel.focusedModelProvider, .typefluxCloud)
    }
}

private final class NoopOllamaModelManager: OllamaModelManaging {
    func ensureModelReady(settingsStore _: SettingsStore) async throws {}
}

private final class NoopLocalSTTModelManager: LocalSTTModelManaging {
    func prepareModel(
        settingsStore _: SettingsStore,
        onUpdate _: (@Sendable (LocalSTTPreparationUpdate) -> Void)?,
    ) async throws {}

    func preparedModelInfo(settingsStore _: SettingsStore) -> LocalSTTPreparedModelInfo? {
        nil
    }

    func isModelAvailable(_: LocalSTTModel) -> Bool {
        false
    }

    func deleteModelFiles(_: LocalSTTModel) throws {}

    func storagePath(for _: LocalSTTConfiguration) -> String {
        "/tmp/typeflux-local-model"
    }
}

private final class EmptyHistoryStore: HistoryStore {
    func save(record _: HistoryRecord) {}
    func list() -> [HistoryRecord] { [] }
    func list(limit _: Int, offset _: Int, searchQuery _: String?) -> [HistoryRecord] { [] }
    func record(id _: UUID) -> HistoryRecord? { nil }
    func delete(id _: UUID) {}
    func purge(olderThanDays _: Int) {}
    func clear() {}
    func exportMarkdown() throws -> URL { FileManager.default.temporaryDirectory }
}
