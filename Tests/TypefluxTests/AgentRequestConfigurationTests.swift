@testable import Typeflux
import XCTest

final class AgentRequestConfigurationTests: XCTestCase {
    func testApplySetsFifteenMinuteTimeout() throws {
        var request = try URLRequest(url: XCTUnwrap(URL(string: "https://example.com")))

        AgentRequestConfiguration.apply(to: &request)

        XCTAssertEqual(request.timeoutInterval, 900, accuracy: 0.001)
    }
}
