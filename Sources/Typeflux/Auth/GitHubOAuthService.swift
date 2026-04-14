import AppKit
import AuthenticationServices
import CryptoKit
import Foundation
import os

/// Handles the GitHub OAuth 2.0 + PKCE flow using ASWebAuthenticationSession.
///
/// Flow:
/// 1. Opens GitHub's OAuth authorization page in a secure browser session.
/// 2. User signs in and grants consent.
/// 3. GitHub redirects back with an authorization code.
/// 4. The code is exchanged for a GitHub access token using PKCE (no client_secret required).
/// 5. The access token is returned for verification by the Typeflux backend.
///
/// Configuration:
/// - Set `GITHUB_OAUTH_CLIENT_ID` in the environment (or via AppServerConfiguration)
///   to a GitHub OAuth App client ID from https://github.com/settings/developers.
/// - Register `dev.typeflux://oauth/github` as an authorized callback URL in your GitHub OAuth App.
@MainActor
struct GitHubOAuthService {
    private static let logger = Logger(subsystem: "dev.typeflux", category: "GitHubOAuthService")

    private static let redirectURI = "dev.typeflux://oauth/github"
    private static let callbackScheme = "dev.typeflux"

    /// Initiates the GitHub sign-in flow and returns a GitHub access token on success.
    ///
    /// - Parameters:
    ///   - clientID: GitHub OAuth App client ID.
    static func signIn(clientID: String) async throws -> String {
        let (codeVerifier, codeChallenge) = makePKCE()
        let state = UUID().uuidString

        var components = URLComponents(string: "https://github.com/login/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "read:user user:email"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        logger.debug("[GitHub OAuth] auth URL: \(components.url!.absoluteString, privacy: .public)")
        let code = try await openAuthSession(url: components.url!, expectedState: state)
        logger.debug("[GitHub OAuth] received code (first 12 chars): \(String(code.prefix(12)), privacy: .public)...")
        return try await exchangeCodeForAccessToken(code: code, codeVerifier: codeVerifier, clientID: clientID)
    }

    // MARK: - Private

    private static func openAuthSession(url: URL, expectedState: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard
                    let callbackURL,
                    let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                    let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                    components.queryItems?.first(where: { $0.name == "state" })?.value == expectedState
                else {
                    continuation.resume(throwing: GitHubAuthError.invalidCallback)
                    return
                }
                continuation.resume(returning: code)
            }
            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = GitHubAuthSessionContextProvider.shared
            session.start()
        }
    }

    private static func exchangeCodeForAccessToken(
        code: String,
        codeVerifier: String,
        clientID: String
    ) async throws -> String {
        var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let params: [String: String] = [
            "client_id": clientID,
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier,
        ]
        request.httpBody = try JSONEncoder().encode(params)

        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
        let rawResponse = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        logger.debug("[GitHub OAuth] token response [\(statusCode, privacy: .public)]: \(rawResponse, privacy: .public)")

        struct TokenResponse: Decodable {
            let accessToken: String?
            let error: String?
            let errorDescription: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case error
                case errorDescription = "error_description"
            }
        }

        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        if let errorCode = response.error {
            let reason = response.errorDescription ?? errorCode
            throw GitHubAuthError.tokenExchangeFailed(reason)
        }
        guard let accessToken = response.accessToken, !accessToken.isEmpty else {
            throw GitHubAuthError.missingAccessToken
        }
        return accessToken
    }

    private static func makePKCE() -> (verifier: String, challenge: String) {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let challengeBytes = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(challengeBytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return (verifier, challenge)
    }
}

// MARK: - Errors

enum GitHubAuthError: LocalizedError {
    case invalidCallback
    case missingAccessToken
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            "GitHub sign-in was cancelled or returned an invalid response."
        case .missingAccessToken:
            "Failed to retrieve GitHub access token."
        case .tokenExchangeFailed(let reason):
            "GitHub token exchange failed: \(reason)"
        }
    }
}

// MARK: - Presentation Context

private final class GitHubAuthSessionContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GitHubAuthSessionContextProvider()

    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
    }
}
