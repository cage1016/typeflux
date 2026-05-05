@testable import Typeflux
import XCTest

final class TypefluxCloudServerErrorMessageTests: XCTestCase {
    func testKnownCodeUsesLocalizedMessageInsteadOfServerMessage() {
        withEnglishLocalization {
            let message = TypefluxCloudServerErrorMessage.userMessage(
                code: "AUTH_INVALID_CREDENTIALS",
                message: "raw backend message",
                fallback: "fallback"
            )

            XCTAssertEqual(message, "The email or password is incorrect.")
        }
    }

    func testCodeNormalizationAcceptsHyphenatedLowercaseValues() {
        XCTAssertEqual(
            TypefluxCloudServerErrorMessage.localizationKey(for: "auth-invalid-credentials"),
            "cloud.error.authInvalidCredentials"
        )
    }

    func testCodeFamilyFallbackHandlesProviderSpecificQuotaCodes() {
        XCTAssertEqual(
            TypefluxCloudServerErrorMessage.localizationKey(for: "asr_daily_quota_exceeded"),
            "cloud.error.quotaExceeded"
        )
    }

    func testUnknownCodeUsesTrimmedServerMessageThenFallback() {
        XCTAssertEqual(
            TypefluxCloudServerErrorMessage.userMessage(
                code: "CUSTOM_ERROR",
                message: "  Custom failure  ",
                fallback: "fallback"
            ),
            "Custom failure"
        )
        XCTAssertEqual(
            TypefluxCloudServerErrorMessage.userMessage(code: "CUSTOM_ERROR", message: "  ", fallback: "fallback"),
            "fallback"
        )
    }

    private func withEnglishLocalization(_ body: () -> Void) {
        let originalLanguage = AppLocalization.shared.language
        AppLocalization.shared.setLanguage(.english)
        defer { AppLocalization.shared.setLanguage(originalLanguage) }
        body()
    }
}
