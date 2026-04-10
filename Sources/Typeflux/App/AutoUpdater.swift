import AppKit
import Foundation

enum AutoUpdater {
    private static let defaultBaseURL = "https://typeflux.gulu.ai"

    /// Overridable via the TYPEFLUX_API_URL environment variable (e.g. for local dev).
    private static var apiBaseURL: String {
        ProcessInfo.processInfo.environment["TYPEFLUX_API_URL"] ?? defaultBaseURL
    }

    private static var downloadURL: URL {
        URL(string: apiBaseURL)!
    }

    static func checkForUpdates(manual: Bool = true) {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        guard var components = URLComponents(string: "\(apiBaseURL)/api/v1/app/update") else { return }
        components.queryItems = [URLQueryItem(name: "version", value: currentVersion)]
        guard let url = components.url else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let error {
                    if manual {
                        showCheckFailedAlert(message: error.localizedDescription)
                    }
                    return
                }

                guard let data else {
                    if manual {
                        showCheckFailedAlert(message: L("updater.checkFailed.noData"))
                    }
                    return
                }

                do {
                    let envelope = try JSONDecoder().decode(UpdateEnvelope.self, from: data)
                    guard let info = envelope.data else {
                        if manual {
                            showCheckFailedAlert(message: envelope.message ?? L("updater.checkFailed.noData"))
                        }
                        return
                    }

                    if info.shouldUpdate {
                        showUpdateAvailableAlert(version: info.latestVersion, releaseNotes: info.releaseNotes)
                    } else if manual {
                        showUpToDateAlert()
                    }
                } catch {
                    if manual {
                        showCheckFailedAlert(message: error.localizedDescription)
                    }
                }
            }
        }.resume()
    }

    private static func showUpdateAvailableAlert(version: String, releaseNotes: String) {
        let alert = NSAlert()
        alert.messageText = L("updater.available.title")
        alert.informativeText = L("updater.available.message", version, releaseNotes)
        alert.addButton(withTitle: L("updater.action.download"))
        alert.addButton(withTitle: L("updater.action.later"))

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(downloadURL)
        }
    }

    private static func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = L("updater.latest.title")
        alert.informativeText = L("updater.latest.message")
        alert.addButton(withTitle: L("common.ok"))
        alert.runModal()
    }

    private static func showCheckFailedAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = L("updater.checkFailed.title")
        alert.informativeText = message
        alert.addButton(withTitle: L("common.ok"))
        alert.runModal()
    }
}

// MARK: - Response models

private struct UpdateEnvelope: Decodable {
    let code: String?
    let message: String?
    let data: UpdateInfo?
}

private struct UpdateInfo: Decodable {
    let latestVersion: String
    let releaseNotes: String
    let shouldUpdate: Bool

    enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
        case releaseNotes = "release_notes"
        case shouldUpdate = "should_update"
    }
}
