@testable import Typeflux
import XCTest

final class AgentExecutionRegistryTests: XCTestCase {
    func testRegisterMarksJobAsRunning() async {
        let registry = AgentExecutionRegistry()
        let jobID = UUID()
        let task = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }

        await registry.register(task, for: jobID)

        let isRunning = await registry.isRunning(jobID: jobID)
        XCTAssertTrue(isRunning)
        task.cancel()
        await registry.finish(jobID: jobID)
    }

    func testCancelRemovesTaskAndCancelsIt() async {
        let registry = AgentExecutionRegistry()
        let jobID = UUID()
        let cancelled = expectation(description: "Task cancelled")

        let task = Task<Void, Never> {
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch is CancellationError {
                cancelled.fulfill()
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        await registry.register(task, for: jobID)
        await registry.cancel(jobID: jobID)

        let isRunning = await registry.isRunning(jobID: jobID)
        XCTAssertFalse(isRunning)
        await fulfillment(of: [cancelled], timeout: 1.0)
    }

    func testFinishRemovesTaskWithoutCancellingIt() async {
        let registry = AgentExecutionRegistry()
        let jobID = UUID()
        let task = Task<Void, Never> {}

        await registry.register(task, for: jobID)
        await registry.finish(jobID: jobID)

        let isRunning = await registry.isRunning(jobID: jobID)
        XCTAssertFalse(isRunning)
    }
}
