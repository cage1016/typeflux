import XCTest
@testable import Typeflux

final class OpenAIEndpointResolverTests: XCTestCase {
    func testResolveKeepsFullTranscriptionEndpoint() throws {
        let configuredURL = try XCTUnwrap(URL(string: "https://api.openai.com/v1/audio/transcriptions"))

        let resolvedURL = OpenAIEndpointResolver.resolve(from: configuredURL, path: "audio/transcriptions")

        XCTAssertEqual(resolvedURL.absoluteString, "https://api.openai.com/v1/audio/transcriptions")
    }

    func testResolveAppendsTranscriptionPathForLegacyBaseURL() throws {
        let configuredURL = try XCTUnwrap(URL(string: "https://api.openai.com/v1"))

        let resolvedURL = OpenAIEndpointResolver.resolve(from: configuredURL, path: "audio/transcriptions")

        XCTAssertEqual(resolvedURL.absoluteString, "https://api.openai.com/v1/audio/transcriptions")
    }

    func testResolveKeepsFullChatCompletionsEndpoint() throws {
        let configuredURL = try XCTUnwrap(URL(string: "https://api.openai.com/v1/chat/completions"))

        let resolvedURL = OpenAIEndpointResolver.resolve(from: configuredURL, path: "chat/completions")

        XCTAssertEqual(resolvedURL.absoluteString, "https://api.openai.com/v1/chat/completions")
    }
}
