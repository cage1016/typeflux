import Foundation

struct BundledLocalModelLocator {
    private let bundledModelsRootURL: URL?

    init(bundledModelsRootURL: URL? = nil) {
        self.bundledModelsRootURL = bundledModelsRootURL
    }

    func storageURLs(for configuration: LocalSTTConfiguration) -> [URL] {
        let relativePath = configuration.model.rawValue + "/"
            + configuration.modelIdentifier.replacingOccurrences(of: "/", with: "--")
        return candidateRootURLs().map {
            $0.appendingPathComponent(relativePath, isDirectory: true)
        }
    }

    private func candidateRootURLs() -> [URL] {
        if let bundledModelsRootURL {
            return [bundledModelsRootURL]
        }

        var urls: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent("BundledModels", isDirectory: true))
        }
        if let resourceURL = Bundle.appResources.resourceURL {
            urls.append(resourceURL.appendingPathComponent("BundledModels", isDirectory: true))
        }
        urls.append(
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources", isDirectory: true)
                .appendingPathComponent("BundledModels", isDirectory: true)
        )

        var seenPaths = Set<String>()
        return urls.filter { seenPaths.insert($0.path).inserted }
    }
}
