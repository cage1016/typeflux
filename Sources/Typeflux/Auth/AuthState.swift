import Foundation
import os

/// Observable auth state manager, shared across the app.
@MainActor
final class AuthState: ObservableObject {
    static let shared = AuthState()

    private let logger = Logger(subsystem: "dev.typeflux", category: "AuthState")

    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var isLoading: Bool = false

    var accessToken: String? {
        guard let stored = KeychainTokenStore.loadToken(),
              stored.expiresAt > Int(Date().timeIntervalSince1970)
        else {
            return nil
        }
        return stored.token
    }

    private init() {
        restoreSession()
    }

    // MARK: - Session Restore

    private func restoreSession() {
        if KeychainTokenStore.isTokenValid {
            userProfile = KeychainTokenStore.loadUserProfile()
            isLoggedIn = true
            Task { await refreshProfile() }
        }
    }

    // MARK: - Login

    func handleLoginSuccess(token: String, expiresAt: Int) async {
        KeychainTokenStore.saveToken(token, expiresAt: expiresAt)
        isLoggedIn = true
        await refreshProfile()
    }

    // MARK: - Logout

    func logout() {
        KeychainTokenStore.clearAll()
        isLoggedIn = false
        userProfile = nil
        logger.info("User logged out")
    }

    // MARK: - Profile Refresh

    func refreshProfile() async {
        guard let token = accessToken else {
            logout()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await AuthAPIService.fetchProfile(token: token)
            userProfile = profile
            KeychainTokenStore.saveUserProfile(profile)
            logger.info("Profile refreshed for \(profile.email)")
        } catch let error as AuthError {
            if shouldInvalidateSession(for: error) {
                logout()
            }
            logger.error("Failed to refresh profile: \(error.localizedDescription)")
        } catch {
            logger.error("Failed to refresh profile: \(error.localizedDescription)")
        }
    }

    private func shouldInvalidateSession(for error: AuthError) -> Bool {
        switch error {
        case .unauthorized:
            true
        case .serverError(let code, _):
            code == "USER_NOT_FOUND"
        case .networkError, .invalidResponse:
            false
        }
    }
}
