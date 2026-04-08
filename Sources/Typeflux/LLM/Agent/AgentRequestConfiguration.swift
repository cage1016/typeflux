import Foundation

enum AgentRequestConfiguration {
    static let timeoutInterval: TimeInterval = 15 * 60

    static func apply(to request: inout URLRequest) {
        request.timeoutInterval = timeoutInterval
    }
}
