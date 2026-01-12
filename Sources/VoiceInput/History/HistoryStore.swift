import Foundation

struct HistoryRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let text: String
    let audioFilePath: String

    init(id: UUID = UUID(), date: Date, text: String, audioFilePath: String) {
        self.id = id
        self.date = date
        self.text = text
        self.audioFilePath = audioFilePath
    }
}

protocol HistoryStore {
    func append(record: HistoryRecord)
    func list() -> [HistoryRecord]
    func purge(olderThanDays days: Int)
    func clear()
    func exportMarkdown() throws -> URL
}
