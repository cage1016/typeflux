@testable import Typeflux
import XCTest

final class KeychainTokenStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        KeychainTokenStore.clearAll()
    }

    override func tearDown() {
        KeychainTokenStore.clearAll()
        super.tearDown()
    }

    // MARK: - Token

    func testSaveAndLoadToken() {
        KeychainTokenStore.saveToken("test-token-123", expiresAt: 9_999_999_999)
        let loaded = KeychainTokenStore.loadToken()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.token, "test-token-123")
        XCTAssertEqual(loaded?.expiresAt, 9_999_999_999)
    }

    func testLoadTokenReturnsNilWhenEmpty() {
        let loaded = KeychainTokenStore.loadToken()
        XCTAssertNil(loaded)
    }

    func testDeleteToken() {
        KeychainTokenStore.saveToken("to-delete", expiresAt: 9_999_999_999)
        KeychainTokenStore.deleteToken()
        XCTAssertNil(KeychainTokenStore.loadToken())
    }

    func testIsTokenValidWithFutureExpiry() {
        let futureExpiry = Int(Date().timeIntervalSince1970) + 3600
        KeychainTokenStore.saveToken("valid-token", expiresAt: futureExpiry)
        XCTAssertTrue(KeychainTokenStore.isTokenValid)
    }

    func testIsTokenValidWithPastExpiry() {
        let pastExpiry = Int(Date().timeIntervalSince1970) - 3600
        KeychainTokenStore.saveToken("expired-token", expiresAt: pastExpiry)
        XCTAssertFalse(KeychainTokenStore.isTokenValid)
    }

    func testIsTokenValidWhenNoToken() {
        XCTAssertFalse(KeychainTokenStore.isTokenValid)
    }

    func testTokenOverwrite() {
        KeychainTokenStore.saveToken("first", expiresAt: 111)
        KeychainTokenStore.saveToken("second", expiresAt: 222)
        let loaded = KeychainTokenStore.loadToken()
        XCTAssertEqual(loaded?.token, "second")
        XCTAssertEqual(loaded?.expiresAt, 222)
    }

    // MARK: - User Profile

    func testSaveAndLoadUserProfile() {
        let profile = UserProfile(
            id: "uid-1",
            email: "user@test.com",
            name: "Test User",
            status: 1,
            provider: "password",
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
        KeychainTokenStore.saveUserProfile(profile)
        let loaded = KeychainTokenStore.loadUserProfile()
        XCTAssertEqual(loaded, profile)
    }

    func testLoadUserProfileReturnsNilWhenEmpty() {
        XCTAssertNil(KeychainTokenStore.loadUserProfile())
    }

    func testDeleteUserProfile() {
        let profile = UserProfile(
            id: "uid-2",
            email: "a@b.com",
            name: "A",
            status: 1,
            provider: "google",
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
        KeychainTokenStore.saveUserProfile(profile)
        KeychainTokenStore.deleteUserProfile()
        XCTAssertNil(KeychainTokenStore.loadUserProfile())
    }

    // MARK: - Clear All

    func testClearAll() {
        KeychainTokenStore.saveToken("tok", expiresAt: 9_999_999_999)
        let profile = UserProfile(
            id: "uid-3",
            email: "c@d.com",
            name: "C",
            status: 1,
            provider: "apple",
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
        KeychainTokenStore.saveUserProfile(profile)

        KeychainTokenStore.clearAll()

        XCTAssertNil(KeychainTokenStore.loadToken())
        XCTAssertNil(KeychainTokenStore.loadUserProfile())
    }
}
