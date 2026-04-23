@testable import Typeflux
import XCTest

final class StatusBarMenuSupportTests: XCTestCase {
    func testRecentTranscriptionRecordsFiltersEmptyFinalTextAndLimitsResults() {
        let base = Date(timeIntervalSince1970: 1_000)
        let records = [
            HistoryRecord(date: base.addingTimeInterval(1), transcriptText: "old"),
            HistoryRecord(date: base.addingTimeInterval(2), transcriptText: "   "),
            HistoryRecord(date: base.addingTimeInterval(3), errorMessage: "failed"),
            HistoryRecord(date: base.addingTimeInterval(4), transcriptText: "new"),
            HistoryRecord(date: base.addingTimeInterval(5), personaResultText: "newest"),
        ]

        let recent = StatusBarMenuSupport.recentTranscriptionRecords(from: records, limit: 2)

        XCTAssertEqual(recent.map(\.finalText), ["newest", "new"])
    }

    func testRecentHistoryTitleFlattensNewlinesAndTruncatesLongText() {
        let record = HistoryRecord(
            date: Date(timeIntervalSince1970: 1_000),
            transcriptText: "first line\nsecond line with a very long transcript body that should be shortened",
        )

        let title = StatusBarMenuSupport.recentHistoryTitle(for: record)

        XCTAssertFalse(title.contains("\n"))
        XCTAssertTrue(title.hasSuffix("..."))
        XCTAssertTrue(title.contains("first line second line"))
    }
}
