import Foundation

enum TypefluxCloudScenario: String, CaseIterable, Sendable {
    case voiceInput = "voice-input"
    case askAnything = "ask-anything"
    case textRewrite = "text-rewrite"
    case automaticVocabulary = "automatic-vocabulary"
    case modelSetup = "model-setup"
}

enum TypefluxCloudRequestHeaders {
    static let scenarioField = "x-scenario"

    static func applyScenario(_ scenario: TypefluxCloudScenario, to request: inout URLRequest) {
        request.setValue(scenario.rawValue, forHTTPHeaderField: scenarioField)
    }

    static func applyingScenario(
        _ scenario: TypefluxCloudScenario,
        to headers: [String: String] = [:],
        provider: LLMRemoteProvider,
    ) -> [String: String] {
        guard provider == .typefluxCloud else { return headers }

        var merged = headers
        merged[scenarioField] = scenario.rawValue
        return merged
    }
}

extension ResolvedLLMConnection {
    func headers(for scenario: TypefluxCloudScenario) -> [String: String] {
        TypefluxCloudRequestHeaders.applyingScenario(
            scenario,
            to: additionalHeaders,
            provider: provider,
        )
    }
}
