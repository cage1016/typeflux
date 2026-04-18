import Foundation

struct LocalModelDownloadSourceCandidate: Equatable {
    let source: ModelDownloadSource
    let latency: TimeInterval?
    let isReachable: Bool
}

protocol LocalModelDownloadSourceResolving {
    func rankedSources(for configuration: LocalSTTConfiguration) async -> [ModelDownloadSource]
}

struct FixedLocalModelDownloadSourceResolver: LocalModelDownloadSourceResolving {
    let sources: [ModelDownloadSource]

    func rankedSources(for configuration: LocalSTTConfiguration) async -> [ModelDownloadSource] {
        let preferred = sources.isEmpty ? [configuration.downloadSource] : sources
        return preferred.removingDuplicatesPreservingOrder()
    }
}

final class NetworkLocalModelDownloadSourceResolver: LocalModelDownloadSourceResolving {
    typealias Probe = @Sendable (URL) async -> LocalModelDownloadSourceCandidate?

    private let probe: Probe
    private let fallbackSources: [ModelDownloadSource]

    init(
        urlSession: URLSession = .shared,
        fallbackSources: [ModelDownloadSource] = ModelDownloadSource.allCases,
    ) {
        self.fallbackSources = fallbackSources
        probe = { url in
            await Self.probe(url: url, urlSession: urlSession)
        }
    }

    init(
        fallbackSources: [ModelDownloadSource] = ModelDownloadSource.allCases,
        probe: @escaping Probe,
    ) {
        self.fallbackSources = fallbackSources
        self.probe = probe
    }

    func rankedSources(for configuration: LocalSTTConfiguration) async -> [ModelDownloadSource] {
        let sources = LocalModelDownloadCatalog.downloadSources(for: configuration.model)
        let probeURLsBySource = Dictionary(
            uniqueKeysWithValues: sources.map {
                ($0, LocalModelDownloadCatalog.probeURLs(for: configuration.model, source: $0))
            },
        )

        let candidates = await withTaskGroup(of: LocalModelDownloadSourceCandidate?.self) { group in
            for source in sources {
                guard let urls = probeURLsBySource[source], !urls.isEmpty else {
                    continue
                }
                group.addTask {
                    await self.probeSource(source: source, urls: urls)
                }
            }

            var results: [LocalModelDownloadSourceCandidate] = []
            for await candidate in group {
                if let candidate {
                    results.append(candidate)
                }
            }
            return results
        }

        let reachableSources = candidates
            .filter(\.isReachable)
            .sorted {
                ($0.latency ?? .greatestFiniteMagnitude) < ($1.latency ?? .greatestFiniteMagnitude)
            }
            .map(\.source)

        let preferred = reachableSources + sources + fallbackSources
        return preferred.removingDuplicatesPreservingOrder()
    }

    private func probeSource(source: ModelDownloadSource, urls: [URL]) async -> LocalModelDownloadSourceCandidate {
        var latencies: [TimeInterval] = []
        for url in urls {
            guard let result = await probe(url), result.isReachable, let latency = result.latency else {
                return LocalModelDownloadSourceCandidate(source: source, latency: nil, isReachable: false)
            }
            latencies.append(latency)
        }

        return LocalModelDownloadSourceCandidate(
            source: source,
            latency: latencies.reduce(0, +),
            isReachable: true,
        )
    }

    private static func probe(url: URL, urlSession: URLSession) async -> LocalModelDownloadSourceCandidate? {
        let start = Date()
        if await isReachable(url: url, method: "HEAD", urlSession: urlSession) {
            return LocalModelDownloadSourceCandidate(
                source: .huggingFace,
                latency: Date().timeIntervalSince(start),
                isReachable: true,
            )
        }

        let rangedStart = Date()
        if await isReachable(url: url, method: "GET", urlSession: urlSession) {
            return LocalModelDownloadSourceCandidate(
                source: .huggingFace,
                latency: Date().timeIntervalSince(rangedStart),
                isReachable: true,
            )
        }

        return LocalModelDownloadSourceCandidate(source: .huggingFace, latency: nil, isReachable: false)
    }

    private static func isReachable(url: URL, method: String, urlSession: URLSession) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 2.5
        if method == "GET" {
            request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        }

        do {
            let (_, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return false
            }
            return (200 ..< 400).contains(http.statusCode)
        } catch {
            return false
        }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicatesPreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
