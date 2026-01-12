import Foundation

final class FileHistoryStore: HistoryStore {
    private let queue = DispatchQueue(label: "history.store")

    private let baseDir: URL
    private let indexURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDir = appSupport.appendingPathComponent("VoiceInput", isDirectory: true)
        indexURL = baseDir.appendingPathComponent("history.json")

        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
    }

    func append(record: HistoryRecord) {
        queue.async {
            var list = self.readIndex()
            list.insert(record, at: 0)
            self.writeIndex(list)
        }
    }

    func list() -> [HistoryRecord] {
        queue.sync {
            readIndex()
        }
    }

    func purge(olderThanDays days: Int) {
        queue.async {
            let cutoff = Date().addingTimeInterval(-TimeInterval(days) * 24 * 3600)
            var list = self.readIndex()

            let (keep, drop) = list.partitioned { $0.date >= cutoff }
            list = keep
            self.writeIndex(list)

            for r in drop {
                try? FileManager.default.removeItem(atPath: r.audioFilePath)
            }
        }
    }

    func clear() {
        queue.async {
            let list = self.readIndex()
            for r in list {
                try? FileManager.default.removeItem(atPath: r.audioFilePath)
            }
            self.writeIndex([])
        }
    }

    func exportMarkdown() throws -> URL {
        let records = list()
        let dateFmt = ISO8601DateFormatter()

        var md = "# VoiceInput History\n\n"
        for r in records {
            md += "## \(dateFmt.string(from: r.date))\n\n"
            md += r.text
            md += "\n\n"
        }

        let url = baseDir.appendingPathComponent("history-\(Int(Date().timeIntervalSince1970)).md")
        try md.data(using: .utf8)?.write(to: url)
        return url
    }

    private func readIndex() -> [HistoryRecord] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder().decode([HistoryRecord].self, from: data)) ?? []
    }

    private func writeIndex(_ list: [HistoryRecord]) {
        do {
            let data = try JSONEncoder().encode(list)
            try data.write(to: indexURL, options: [.atomic])
        } catch {
            // ignore
        }
    }
}

private extension Array {
    func partitioned(_ isIncluded: (Element) -> Bool) -> ([Element], [Element]) {
        var a: [Element] = []
        var b: [Element] = []
        a.reserveCapacity(count)
        b.reserveCapacity(count)
        for e in self {
            if isIncluded(e) { a.append(e) } else { b.append(e) }
        }
        return (a, b)
    }
}
