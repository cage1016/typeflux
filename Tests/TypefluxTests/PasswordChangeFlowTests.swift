@testable import Typeflux
import XCTest

final class PasswordChangeFlowTests: XCTestCase {
    func testPresentFormShowsPasswordChangeForm() {
        var flow = PasswordChangeFlow()

        flow.presentForm()

        XCTAssertEqual(flow.activeDialog, .form)
    }

    func testShowSuccessConfirmationReplacesFormDialog() {
        var flow = PasswordChangeFlow()
        flow.presentForm()

        flow.showSuccessConfirmation()

        XCTAssertEqual(flow.activeDialog, .successConfirmation)
    }

    func testDismissClearsActiveDialog() {
        var flow = PasswordChangeFlow()
        flow.showSuccessConfirmation()

        flow.dismiss()

        XCTAssertNil(flow.activeDialog)
    }
}
