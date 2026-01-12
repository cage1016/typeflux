import Foundation

struct ErrorLogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let message: String
}

final class ErrorLogStore: ObservableObject {
    static let shared = ErrorLogStore()

    @Published private(set) var entries: [ErrorLogEntry] = []

    private let maxEntries = 100

    func log(_ message: String) {
        let entry = ErrorLogEntry(date: Date(), message: message)
        DispatchQueue.main.async {
            self.entries.insert(entry, at: 0)
            if self.entries.count > self.maxEntries {
                self.entries = Array(self.entries.prefix(self.maxEntries))
            }
        }
        NSLog("[ErrorLog] \(message)")
    }

    func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }
}
