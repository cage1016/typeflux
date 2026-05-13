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

    func testResolveAPIBaseURLsUsesBuiltInDefaultListWhenNoConfigurationIsProvided() {
        XCTAssertEqual(
            AppServerConfiguration.resolveAPIBaseURLs(rawMulti: nil, rawSingle: nil),
            ["https://api.typeflux.app", "https://typeflux-api.aicode.cc"]
        )
    }

    func testResolveAPIBaseURLsUsesLegacySingleEndpointBeforeBuiltInDefaults() {
        XCTAssertEqual(
            AppServerConfiguration.resolveAPIBaseURLs(rawMulti: nil, rawSingle: "https://legacy.example"),
            ["https://legacy.example"]
        )
    }

    func testResolveAPIBaseURLsUsesMultiEndpointBeforeLegacySingleEndpoint() {
        XCTAssertEqual(
            AppServerConfiguration.resolveAPIBaseURLs(
                rawMulti: "https://a.example, https://b.example",
                rawSingle: "https://legacy.example"
            ),
            ["https://a.example", "https://b.example"]
        )
    }
}
