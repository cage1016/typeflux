import Foundation

enum AppServerConfiguration {
    private static let defaultBaseURL = "https://typeflux.gulu.ai"

    static var apiBaseURL: String {
        ProcessInfo.processInfo.environment["TYPEFLUX_API_URL"] ?? defaultBaseURL
    }
}
