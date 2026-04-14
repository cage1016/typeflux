@testable import Typeflux
import XCTest

final class LoginViewPolicyGuardTests: XCTestCase {
    private var originalLanguage: AppLanguage!

    override func setUp() {
        super.setUp()
        originalLanguage = AppLocalization.shared.language
    }

    override func tearDown() {
        AppLocalization.shared.setLanguage(originalLanguage)
        originalLanguage = nil
        super.tearDown()
    }

    func testGoogleLoginPreflightBlocksWhenPoliciesNotAccepted() {
        AppLocalization.shared.setLanguage(.english)

        let errorMessage = LoginGooglePreflight.errorMessage(
            for: .enterEmail,
            hasAcceptedPolicies: false
        )

        XCTAssertEqual(
            errorMessage,
            "Please accept the Terms of Service and Privacy Policy first."
        )
    }

    func testGoogleLoginPreflightAllowsAttemptAfterPoliciesAccepted() {
        let errorMessage = LoginGooglePreflight.errorMessage(
            for: .enterEmail,
            hasAcceptedPolicies: true
        )

        XCTAssertNil(errorMessage)
    }

    func testGoogleLoginPreflightDoesNotRequirePoliciesOutsideEntryStep() {
        let errorMessage = LoginGooglePreflight.errorMessage(
            for: .login,
            hasAcceptedPolicies: false
        )

        XCTAssertNil(errorMessage)
    }

    func testGoogleLoginPreflightUsesCurrentLocalization() {
        AppLocalization.shared.setLanguage(.simplifiedChinese)

        let errorMessage = LoginGooglePreflight.errorMessage(
            for: .enterEmail,
            hasAcceptedPolicies: false
        )

        XCTAssertEqual(errorMessage, "请先同意《用户协议》和《隐私政策》。")
    }

    func testSocialLoginLayoutIncludesProvidersInStableOrder() {
        let providers = SocialLoginLayout.enabledProviders(
            googleClientID: "google-client",
            githubClientID: "github-client"
        )

        XCTAssertEqual(providers, [.google, .github])
    }

    func testSocialLoginLayoutOmitsUnavailableProviders() {
        let googleOnly = SocialLoginLayout.enabledProviders(
            googleClientID: "google-client",
            githubClientID: ""
        )
        let githubOnly = SocialLoginLayout.enabledProviders(
            googleClientID: "",
            githubClientID: "github-client"
        )
        let none = SocialLoginLayout.enabledProviders(
            googleClientID: "",
            githubClientID: ""
        )

        XCTAssertEqual(googleOnly, [.google])
        XCTAssertEqual(githubOnly, [.github])
        XCTAssertTrue(none.isEmpty)
    }
}
