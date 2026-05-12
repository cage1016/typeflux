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

    func testBillingErrorParsesSubscriptionRequiredHTTPBody() {
        let body = Data(#"{"code":"SUBSCRIPTION_REQUIRED","message":"active subscription required"}"#.utf8)
        let error = TypefluxCloudBillingError.fromHTTPStatus(402, bodyData: body)

        XCTAssertEqual(error?.reason, .subscriptionRequired)
    }

    func testBillingErrorParsesQuotaAndPaymentCodes() {
        XCTAssertEqual(
            TypefluxCloudBillingError.fromServerCode("INSUFFICIENT_CREDITS", message: nil)?.reason,
            .quotaExceeded
        )
        XCTAssertEqual(
            TypefluxCloudBillingError.fromServerCode("PAYMENT_REQUIRED", message: nil)?.reason,
            .subscriptionRequired
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
