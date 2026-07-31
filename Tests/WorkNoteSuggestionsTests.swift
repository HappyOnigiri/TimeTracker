import Foundation
import Testing
@testable import TimeTracker

struct WorkNoteSuggestionsTests {
    @Test("重複する notes は 1 つにまとめられる")
    func deduplicates() {
        let project = Project(name: "A")
        let log1 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 10, 9, 0),
                           endDate: TestSupport.date(2025, 1, 10, 10, 0),
                           notes: ["設計"])
        let log2 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 11, 9, 0),
                           endDate: TestSupport.date(2025, 1, 11, 10, 0),
                           notes: ["設計"])
        let result = WorkNoteSuggestions.candidates(from: [log1, log2])
        #expect(result == ["設計"])
    }

    @Test("最終使用日が新しいものが先頭に来る")
    func sortsByLatestDate() {
        let project = Project(name: "A")
        let log1 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 10, 9, 0),
                           endDate: TestSupport.date(2025, 1, 10, 10, 0),
                           notes: ["古い作業"])
        let log2 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 15, 9, 0),
                           endDate: TestSupport.date(2025, 1, 15, 10, 0),
                           notes: ["新しい作業"])
        let result = WorkNoteSuggestions.candidates(from: [log1, log2])
        #expect(result == ["新しい作業", "古い作業"])
    }

    @Test("空文字列と空白のみの文字列は除外される")
    func excludesEmptyAndWhitespace() {
        let project = Project(name: "A")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 10, 0),
                          notes: ["", "  ", "有効"])
        let result = WorkNoteSuggestions.candidates(from: [log])
        #expect(result == ["有効"])
    }

    @Test("notes が空のログのみの場合は空配列を返す")
    func returnsEmptyForNoNotes() {
        let project = Project(name: "A")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 10, 0),
                          notes: [])
        let result = WorkNoteSuggestions.candidates(from: [log])
        #expect(result.isEmpty)
    }

    @Test("limit を指定すると最終使用日の新しい順に切り捨てられる")
    func truncatesToLimit() {
        let project = Project(name: "A")
        let logs = (1...5).map { day in
            TimeLog(project: project,
                    startDate: TestSupport.date(2025, 1, day, 9, 0),
                    endDate: TestSupport.date(2025, 1, day, 10, 0),
                    notes: ["作業\(day)"])
        }
        let result = WorkNoteSuggestions.candidates(from: logs, limit: 2)
        #expect(result == ["作業5", "作業4"])
    }

    @Test("limit に .max を渡すと既定の 20 件を超えても全件返る")
    func returnsAllCandidatesWithMaxLimit() {
        let project = Project(name: "A")
        let logs = (1...25).map { index in
            TimeLog(project: project,
                    startDate: TestSupport.date(2025, 1, 1, 9, index),
                    endDate: TestSupport.date(2025, 1, 1, 10, index),
                    notes: ["作業\(index)"])
        }
        #expect(WorkNoteSuggestions.candidates(from: logs).count == 20)
        #expect(WorkNoteSuggestions.candidates(from: logs, limit: .max).count == 25)
    }

    @Test("最終使用日が同じ候補は文言の昇順で安定して並ぶ")
    func sortsTiesByNameAscending() {
        let project = Project(name: "A")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 10, 0),
                          notes: ["ccc", "aaa", "bbb"])
        let result = WorkNoteSuggestions.candidates(from: [log])
        #expect(result == ["aaa", "bbb", "ccc"])
    }

    @Test("endDate が nil のログは startDate を参照日として使う")
    func usesStartDateWhenEndDateIsNil() {
        let project = Project(name: "A")
        let log1 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 15, 9, 0),
                           endDate: nil,
                           notes: ["計測中"])
        let log2 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 10, 9, 0),
                           endDate: TestSupport.date(2025, 1, 10, 10, 0),
                           notes: ["完了済み"])
        let result = WorkNoteSuggestions.candidates(from: [log1, log2])
        #expect(result == ["計測中", "完了済み"])
    }
}
