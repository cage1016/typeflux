@testable import Typeflux
import AppKit
import XCTest

@MainActor
final class LoginWindowControllerTests: XCTestCase {
    func testDefaultWindowSizePreservesDialogWidth() {
        XCTAssertEqual(LoginWindowController.defaultWindowSize.width, 520)
    }

    func testDefaultWindowSizeProvidesEnoughVerticalSpaceForLoginContent() {
        XCTAssertGreaterThanOrEqual(LoginWindowController.defaultWindowSize.height, 620)
    }
}
