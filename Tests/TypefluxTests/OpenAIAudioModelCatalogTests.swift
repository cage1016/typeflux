import XCTest
@testable import Typeflux

final class OpenAIAudioModelCatalogTests: XCTestCase {
    func testWhisperBuiltInOptionsMatchSupportedValues() {
        XCTAssertEqual(
            OpenAIAudioModelCatalog.whisperModels,
            ["gpt-4o-mini-transcribe", "whisper-1", "gpt-4o-transcribe"]
        )
    }

    func testMultimodalBuiltInModelsMatchSupportedValues() {
        XCTAssertEqual(
            OpenAIAudioModelCatalog.multimodalModels,
            ["gpt-4o-mini-audio-preview", "gpt-4o-audio-preview", "gpt-audio-mini"]
        )
    }

    func testBuiltInEndpointsMatchConfiguredDefaults() {
        XCTAssertEqual(
            OpenAIAudioModelCatalog.whisperEndpoints,
            ["https://api.openai.com/v1/audio/transcriptions"]
        )
        XCTAssertEqual(
            OpenAIAudioModelCatalog.multimodalEndpoints,
            ["https://api.openai.com/v1/chat/completions"]
        )
    }
}
