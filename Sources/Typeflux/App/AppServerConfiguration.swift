import Foundation

enum AppServerConfiguration {
    private static let defaultBaseURL = "https://typeflux.gulu.ai"
    private static let defaultGoogleOAuthClientID = "567492048493-35tbcha1ofbuku73jh1r8q9jn0fgl010.apps.googleusercontent.com"

    static var apiBaseURL: String {
        ProcessInfo.processInfo.environment["TYPEFLUX_API_URL"] ?? defaultBaseURL
    }

    /// Google OAuth 2.0 Client ID (Desktop application type) from Google Cloud Console.
    /// Set via the GOOGLE_OAUTH_CLIENT_ID environment variable.
    /// When empty, Google Sign-In is disabled in the login UI.
    static var googleOAuthClientID: String {
        ProcessInfo.processInfo.environment["GOOGLE_OAUTH_CLIENT_ID"] ?? defaultGoogleOAuthClientID
    }
}
