import Foundation

enum OpenAIEndpointResolver {
    static func resolve(from configuredURL: URL, path expectedPath: String) -> URL {
        if matchesEndpoint(configuredURL, expectedPath: expectedPath) {
            return configuredURL
        }

        let sanitizedPath = expectedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return configuredURL.appendingPathComponent(sanitizedPath)
    }

    private static func matchesEndpoint(_ url: URL, expectedPath: String) -> Bool {
        let normalizedURLPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let normalizedExpectedPath = expectedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        return normalizedURLPath.hasSuffix(normalizedExpectedPath)
    }
}
