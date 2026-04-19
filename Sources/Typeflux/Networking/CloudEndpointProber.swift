import Foundation

/// Result of a single ping probe against a Typeflux Cloud endpoint.
struct CloudEndpointProbeResult: Sendable {
    let latencyMs: Double
    let serverID: String?
    let serverVersion: String?
    let nonceMatches: Bool
}

/// Errors raised by `CloudEndpointProbing` implementations.
enum CloudEndpointProbeError: LocalizedError {
    case invalidURL
    case timedOut
    case transport(Error)
    case httpStatus(Int)
    case decoding(Error)
    case nonceMismatch

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid endpoint URL."
        case .timedOut:
            return "Probe timed out."
        case .transport(let error):
            return "Probe transport error: \(error.localizedDescription)"
        case .httpStatus(let code):
            return "Probe returned HTTP \(code)."
        case .decoding(let error):
            return "Probe response could not be decoded: \(error.localizedDescription)"
        case .nonceMismatch:
            return "Probe response did not echo the expected nonce."
        }
    }
}

/// Sends a single ping request against a Typeflux Cloud endpoint and returns
/// the measured latency along with server-reported metadata.
protocol CloudEndpointProbing: Sendable {
    func probe(baseURL: URL, nonce: String, timeout: TimeInterval) async throws -> CloudEndpointProbeResult
}

/// Production prober that hits `<baseURL>/api/v1/ping?nonce=<nonce>` over HTTPS.
struct HTTPCloudEndpointProber: CloudEndpointProbing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func probe(baseURL: URL, nonce: String, timeout: TimeInterval) async throws -> CloudEndpointProbeResult {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw CloudEndpointProbeError.invalidURL
        }
        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = trimmedPath.isEmpty ? "/api/v1/ping" : "/" + trimmedPath + "/api/v1/ping"
        components.queryItems = [URLQueryItem(name: "nonce", value: nonce)]
        guard let url = components.url else {
            throw CloudEndpointProbeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")

        let start = ContinuousClock.now

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CloudEndpointProbeError.timedOut
        } catch {
            throw CloudEndpointProbeError.transport(error)
        }

        let elapsed = ContinuousClock.now - start

        guard let http = response as? HTTPURLResponse else {
            throw CloudEndpointProbeError.invalidURL
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CloudEndpointProbeError.httpStatus(http.statusCode)
        }

        let envelope: PingEnvelope
        do {
            envelope = try JSONDecoder().decode(PingEnvelope.self, from: data)
        } catch {
            throw CloudEndpointProbeError.decoding(error)
        }

        let payload = envelope.data
        let nonceMatches = payload?.nonce == nonce
        if !nonceMatches {
            throw CloudEndpointProbeError.nonceMismatch
        }

        return CloudEndpointProbeResult(
            latencyMs: durationToMilliseconds(elapsed),
            serverID: payload?.serverID,
            serverVersion: payload?.version,
            nonceMatches: true
        )
    }

    private func durationToMilliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        let secondsAsMs = Double(components.seconds) * 1000.0
        let attoAsMs = Double(components.attoseconds) / 1_000_000_000_000_000.0
        return secondsAsMs + attoAsMs
    }
}

private struct PingEnvelope: Decodable {
    let code: String?
    let data: PingData?
}

private struct PingData: Decodable {
    let pong: Bool?
    let nonce: String?
    let serverID: String?
    let serverTimeMs: Int64?
    let version: String?

    enum CodingKeys: String, CodingKey {
        case pong
        case nonce
        case serverID = "server_id"
        case serverTimeMs = "server_time_ms"
        case version
    }
}
