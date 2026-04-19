@testable import Typeflux
import XCTest

final class AppServerConfigurationTests: XCTestCase {
    func testParseListReturnsNilForEmptyInput() {
        XCTAssertNil(AppServerConfiguration.parseList(nil))
        XCTAssertNil(AppServerConfiguration.parseList(""))
    }

    func testParseListReturnsNilWhenAllSegmentsAreBlank() {
        XCTAssertNil(AppServerConfiguration.parseList(", , ,"))
    }

    func testParseListSplitsAndTrimsCommaSeparatedValues() {
        let result = AppServerConfiguration.parseList(" https://a.example , https://b.example ,https://c.example")
        XCTAssertEqual(result, ["https://a.example", "https://b.example", "https://c.example"])
    }

    func testParseListPreservesOrderAndDeduplicates() {
        let result = AppServerConfiguration.parseList("https://a.example, https://b.example, https://a.example")
        XCTAssertEqual(result, ["https://a.example", "https://b.example"])
    }

    func testApiBaseURLsAlwaysHasAtLeastOneEntry() {
        XCTAssertFalse(AppServerConfiguration.apiBaseURLs.isEmpty)
    }

    func testApiBaseURLMatchesFirstApiBaseURL() {
        XCTAssertEqual(AppServerConfiguration.apiBaseURL, AppServerConfiguration.apiBaseURLs.first)
    }
}
