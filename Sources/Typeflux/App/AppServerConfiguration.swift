import Foundation

enum AppServerConfiguration {
    private static let defaultBaseURL = "https://typeflux.gulu.ai"
    private static let defaultGoogleOAuthClientID = "567492048493-bh84p3mfjfjimsfvga7pil3cc373d389.apps.googleusercontent.com"
    private static let defaultGoogleCloudOAuthClientID = "86325451552-drgdrf01ffjo0on25a1psmg4mpvlo8gi.apps.googleusercontent.com"
    private static let defaultGithubOAuthClientID = "Ov23lidqnPDEOAvE8RvH"

    private static func configuredValue(
        environmentKey: String,
        infoPlistKey: String,
        default defaultValue: String
    ) -> String {
        if let value = ProcessInfo.processInfo.environment[environmentKey], !value.isEmpty {
            return value
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String, !value.isEmpty {
            return value
        }
        return defaultValue
    }

    static var apiBaseURL: String {
        configuredValue(
            environmentKey: "TYPEFLUX_API_URL",
            infoPlistKey: "TYPEFLUX_API_URL",
            default: defaultBaseURL
        )
    }

    /// Google OAuth 2.0 Client ID from Google Cloud Console.
    /// Recommended: create an iOS-type client (no secret required).
    /// Desktop-type clients also work but require GOOGLE_OAUTH_CLIENT_SECRET as well.
    /// When empty, Google Sign-In is disabled in the login UI.
    static var googleOAuthClientID: String {
        configuredValue(
            environmentKey: "GOOGLE_OAUTH_CLIENT_ID",
            infoPlistKey: "GOOGLE_OAUTH_CLIENT_ID",
            default: defaultGoogleOAuthClientID
        )
    }

    /// Google OAuth 2.0 Client Secret — only required for Desktop-type clients.
    /// iOS-type clients are public clients and do not need a secret.
    /// Leave empty (default) when using an iOS-type client ID.
    static var googleOAuthClientSecret: String {
        configuredValue(
            environmentKey: "GOOGLE_OAUTH_CLIENT_SECRET",
            infoPlistKey: "GOOGLE_OAUTH_CLIENT_SECRET",
            default: ""
        )
    }

    /// Google OAuth 2.0 Client ID used only for direct Google Cloud Speech-to-Text access.
    /// Keep this separate from Google Sign-In so adding Cloud API scopes does not affect login verification.
    /// Falls back to the sign-in client until a dedicated Cloud client is configured.
    static var googleCloudOAuthClientID: String {
        configuredValue(
            environmentKey: "GOOGLE_CLOUD_OAUTH_CLIENT_ID",
            infoPlistKey: "GOOGLE_CLOUD_OAUTH_CLIENT_ID",
            default: defaultGoogleCloudOAuthClientID
        )
    }

    /// Google OAuth 2.0 Client Secret for the dedicated Google Cloud Speech client.
    /// Required only if that client is a Desktop app client.
    static var googleCloudOAuthClientSecret: String {
        configuredValue(
            environmentKey: "GOOGLE_CLOUD_OAUTH_CLIENT_SECRET",
            infoPlistKey: "GOOGLE_CLOUD_OAUTH_CLIENT_SECRET",
            default: googleOAuthClientSecret
        )
    }

    /// GitHub OAuth App client ID from https://github.com/settings/developers.
    /// When empty, GitHub Sign-In is disabled in the login UI.
    static var githubOAuthClientID: String {
        configuredValue(
            environmentKey: "GITHUB_OAUTH_CLIENT_ID",
            infoPlistKey: "GITHUB_OAUTH_CLIENT_ID",
            default: defaultGithubOAuthClientID
        )
    }

}
