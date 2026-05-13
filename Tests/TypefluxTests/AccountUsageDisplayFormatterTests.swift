@testable import Typeflux
import XCTest

final class AccountUsageDisplayFormatterTests: XCTestCase {
    func testCountUsesGroupedRawValueForSmallNumbers() {
        XCTAssertEqual(AccountUsageDisplayFormatter.count(0), "0")
        XCTAssertEqual(AccountUsageDisplayFormatter.count(999), "999")
        XCTAssertEqual(AccountUsageDisplayFormatter.count(9999), "9,999")
    }

    func testCountUsesCompactSuffixesForLargeNumbers() {
        XCTAssertEqual(AccountUsageDisplayFormatter.count(10000), "10K")
        XCTAssertEqual(AccountUsageDisplayFormatter.count(10235), "10.2K")
        XCTAssertEqual(AccountUsageDisplayFormatter.count(1_234_567), "1.23M")
        XCTAssertEqual(AccountUsageDisplayFormatter.count(12_345_678), "12.3M")
        XCTAssertEqual(AccountUsageDisplayFormatter.count(1_234_567_890), "1.23B")
        XCTAssertEqual(AccountUsageDisplayFormatter.count(1_234_567_890_123), "1.23T")
    }

    func testCountPromotesRoundedBoundaryToNextSuffix() {
        XCTAssertEqual(AccountUsageDisplayFormatter.count(999_950), "1M")
    }

    func testCountPreservesNegativeSign() {
        XCTAssertEqual(AccountUsageDisplayFormatter.count(-12345), "-12.3K")
    }
}
