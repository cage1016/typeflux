import XCTest
@testable import Typeflux

final class LLMRemoteProviderTests: XCTestCase {
    private let defaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        clearLLMKeys()
    }

    override func tearDown() {
        clearLLMKeys()
        super.tearDown()
    }

    func testCustomProviderFallsBackToLegacyValues() {
        defaults.set(LLMRemoteProvider.custom.rawValue, forKey: "llm.remote.provider")
        defaults.set("https://example.com/v1", forKey: "llm.baseURL")
        defaults.set("custom-model", forKey: "llm.model")
        defaults.set("sk-custom", forKey: "llm.apiKey")

        let store = SettingsStore()

        XCTAssertEqual(store.llmBaseURL(for: .custom), "https://example.com/v1")
        XCTAssertEqual(store.llmModel(for: .custom), "custom-model")
        XCTAssertEqual(store.llmAPIKey(for: .custom), "sk-custom")
    }

    func testFixedProvidersKeepIndependentModelAndAPIKey() {
        let store = SettingsStore()

        store.setLLMModel("gpt-4o", for: .openAI)
        store.setLLMAPIKey("sk-openai", for: .openAI)
        store.setLLMModel("deepseek-chat", for: .deepSeek)
        store.setLLMAPIKey("sk-deepseek", for: .deepSeek)

        XCTAssertEqual(store.llmBaseURL(for: .openAI), "https://api.openai.com/v1")
        XCTAssertEqual(store.llmBaseURL(for: .deepSeek), "https://api.deepseek.com")
        XCTAssertEqual(store.llmModel(for: .openAI), "gpt-4o")
        XCTAssertEqual(store.llmModel(for: .deepSeek), "deepseek-chat")
        XCTAssertEqual(store.llmAPIKey(for: .openAI), "sk-openai")
        XCTAssertEqual(store.llmAPIKey(for: .deepSeek), "sk-deepseek")
    }

    func testProviderIDRoundTrip() {
        for provider in LLMRemoteProvider.allCases {
            XCTAssertEqual(LLMRemoteProvider.from(providerID: provider.studioProviderID), provider)
        }
    }

    private func clearLLMKeys() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("llm.") {
            defaults.removeObject(forKey: key)
        }
    }
}
