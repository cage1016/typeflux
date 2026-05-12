@testable import Typeflux
import XCTest

final class TypefluxCloudRequestHeadersTests: XCTestCase {
    func testClientIdentityStoreGeneratesAndPersistsClientID() {
        let suiteName = "TypefluxCloudRequestHeadersTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = TypefluxCloudClientIdentityStore(defaults: defaults, key: "client-id")

        let first = store.clientID()
        let second = store.clientID()

        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, second)
        XCTAssertEqual(defaults.string(forKey: "client-id"), first)
    }

    func testApplyClientInfoAddsUserAgentAndClientMetadataHeaders() {
        var request = URLRequest(url: URL(string: "https://cloud.typeflux.dev/api/v1/me")!)

        TypefluxCloudRequestHeaders.applyClientInfo(to: &request, provider: .fixture)

        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "Typeflux/1.2.3")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Language"), "zh-Hans-US, en-US;q=0.9")
        XCTAssertEqual(request.value(forHTTPHeaderField: TypefluxCloudRequestHeaders.clientIDField), "client-123")
        XCTAssertEqual(request.value(forHTTPHeaderField: TypefluxCloudRequestHeaders.clientLocaleField), "zh_Hans_US")
        XCTAssertEqual(request.value(forHTTPHeaderField: TypefluxCloudRequestHeaders.clientLanguagesField), "zh-Hans-US,en-US")
        XCTAssertEqual(request.value(forHTTPHeaderField: TypefluxCloudRequestHeaders.clientOSField), "macOS")
        XCTAssertEqual(request.value(forHTTPHeaderField: TypefluxCloudRequestHeaders.clientOSVersionField), "14.6.1")
        XCTAssertEqual(request.value(forHTTPHeaderField: TypefluxCloudRequestHeaders.clientArchitectureField), "arm64")
    }

    func testTypefluxCloudScenarioHeadersIncludeClientInfo() {
        let headers = TypefluxCloudRequestHeaders.applyingScenario(
            .askAnything,
            to: ["x-request-id": "req-1"],
            provider: .typefluxCloud,
            clientInfoProvider: .fixture
        )

        XCTAssertEqual(headers["x-request-id"], "req-1")
        XCTAssertEqual(headers[TypefluxCloudRequestHeaders.scenarioField], "ask-anything")
        XCTAssertEqual(headers["User-Agent"], "Typeflux/1.2.3")
        XCTAssertEqual(headers[TypefluxCloudRequestHeaders.clientIDField], "client-123")
    }

    func testNonTypefluxCloudScenarioHeadersDoNotIncludeClientInfo() {
        let headers = TypefluxCloudRequestHeaders.applyingScenario(
            .askAnything,
            to: ["x-request-id": "req-1"],
            provider: .openAI,
            clientInfoProvider: .fixture
        )

        XCTAssertEqual(headers["x-request-id"], "req-1")
        XCTAssertNil(headers[TypefluxCloudRequestHeaders.scenarioField])
        XCTAssertNil(headers["User-Agent"])
        XCTAssertNil(headers[TypefluxCloudRequestHeaders.clientIDField])
    }

    func testApplyPersonaIDAddsPersonaHeader() {
        let personaID = UUID(uuidString: "2A7A4A74-A8AC-4F3C-9FB1-5A433EDFA001")!
        var request = URLRequest(url: URL(string: "https://cloud.typeflux.dev/api/v1/asr/ws/default")!)

        TypefluxCloudRequestHeaders.applyPersonaID(personaID, to: &request)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: TypefluxCloudRequestHeaders.personaIDField),
            personaID.uuidString,
        )
    }

    func testApplyPersonaIDSkipsNilPersonaID() {
        var request = URLRequest(url: URL(string: "https://cloud.typeflux.dev/api/v1/asr/ws/default")!)

        TypefluxCloudRequestHeaders.applyPersonaID(nil, to: &request)

        XCTAssertNil(request.value(forHTTPHeaderField: TypefluxCloudRequestHeaders.personaIDField))
    }
}

private extension TypefluxCloudClientInfoProvider {
    static let fixture = TypefluxCloudClientInfoProvider {
        TypefluxCloudClientInfo(
            appName: "Typeflux",
            appVersion: "1.2.3",
            clientID: "client-123",
            localeIdentifier: "zh_Hans_US",
            preferredLanguages: ["zh-Hans-US", "en-US"],
            osName: "macOS",
            osVersion: "14.6.1",
            architecture: "arm64",
        )
    }
}
