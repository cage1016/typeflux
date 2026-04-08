import Foundation

actor AgentExecutionRegistry {
    private var tasks: [UUID: Task<Void, Never>] = [:]

    func register(_ task: Task<Void, Never>, for jobID: UUID) {
        tasks[jobID]?.cancel()
        tasks[jobID] = task
    }

    func cancel(jobID: UUID) {
        tasks.removeValue(forKey: jobID)?.cancel()
    }

    func finish(jobID: UUID) {
        tasks.removeValue(forKey: jobID)
    }

    func isRunning(jobID: UUID) -> Bool {
        tasks[jobID] != nil
    }
}
