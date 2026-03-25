import Foundation

final class OpenAICompatibleLLMService: LLMService {
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func streamEdit(selectedText: String, instruction: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let text = try await streamEditInternal(selectedText: selectedText, instruction: instruction, continuation: continuation)
                    continuation.finish()
                    _ = text
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func streamEditInternal(
        selectedText: String,
        instruction: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws -> String {
        guard let baseURL = URL(string: settingsStore.llmBaseURL), !settingsStore.llmAPIKey.isEmpty else {
            throw NSError(domain: "LLM", code: 1)
        }

        let model = settingsStore.llmModel.isEmpty ? "gpt-4o-mini" : settingsStore.llmModel

        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settingsStore.llmAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = "You are a text editing assistant. Return ONLY the final rewritten text. Do not include explanations."
        let userPrompt = "Selected text:\n\(selectedText)\n\nInstruction:\n\(instruction)\n\nReturn only the final text."

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        NetworkDebugLogger.logRequest(request)

        var final = ""

        do {
            for try await line in try await SSEClient.lines(for: request) {
                if line == "[DONE]" { break }

                guard let data = line.data(using: .utf8) else { continue }
                let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                let choices = obj?["choices"] as? [[String: Any]]
                let delta = choices?.first?["delta"] as? [String: Any]
                let content = delta?["content"] as? String
                if let content {
                    final += content
                    continuation.yield(content)
                }
            }
        } catch {
            NetworkDebugLogger.logError(context: "LLM stream failed", error: error)
            throw error
        }

        NetworkDebugLogger.logMessage("LLM final result: \(final.isEmpty ? "<empty stream result>" : final)")

        return final
    }
}

enum SSEClient {
    static func lines(for request: URLRequest) async throws -> AsyncThrowingStream<String, Error> {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            NetworkDebugLogger.logResponse(response, bodyDescription: "<invalid non-http response>")
            throw NSError(domain: "SSE", code: 1)
        }

        if !(200..<300).contains(http.statusCode) {
            var errorBodyData = Data()
            for try await byte in bytes {
                errorBodyData.append(byte)
            }
            NetworkDebugLogger.logResponse(http, data: errorBodyData)
            let errorBody = String(data: errorBodyData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SSE", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(errorBody)"])
        }

        NetworkDebugLogger.logResponse(http, bodyDescription: "<stream opened>")

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var buffer = ""
                    for try await byte in bytes {
                        let scalar = UnicodeScalar(byte)
                        buffer.append(Character(scalar))
                        if buffer.hasSuffix("\n") {
                            let line = buffer.trimmingCharacters(in: .newlines)
                            buffer = ""

                            if line.hasPrefix("data:") {
                                let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                                continuation.yield(payload)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    NetworkDebugLogger.logError(context: "SSE stream parsing failed", error: error)
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
