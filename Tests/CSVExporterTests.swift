import Foundation
import Testing
@testable import TimeTracker

struct CSVExporterTests {
    @Test("ヘッダと完了ログの行が出力される")
    func emitsHeaderAndRows() {
        let project = Project(name: "実装")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 10, 0))
        let csv = CSVExporter.makeCSV(logs: [log])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines[0] == "project,start,end,duration_seconds,notes")
        #expect(lines.count == 2)
        #expect(lines[1].hasPrefix("実装,"))
        #expect(lines[1].hasSuffix(",3600,"))
    }

    @Test("計測中ログは除外される")
    func excludesRunningLogs() {
        let project = Project(name: "X")
        let running = TimeLog(project: project, startDate: TestSupport.date(2025, 1, 10, 9, 0), endDate: nil)
        let csv = CSVExporter.makeCSV(logs: [running])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 1) // ヘッダのみ
    }

    @Test("clipTo 指定で月境界をまたぐログがクリップされる")
    func clipsToRange() {
        let project = Project(name: "実装")
        // 5/31 23:00 〜 6/1 02:00（3時間）を 6 月でクリップ → 6/1 00:00〜02:00 の 2 時間。
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 5, 31, 23, 0),
                          endDate: TestSupport.date(2025, 6, 1, 2, 0))
        let june = TestSupport.date(2025, 6, 1, 0, 0)...TestSupport.date(2025, 7, 1, 0, 0)
        let csv = CSVExporter.makeCSV(logs: [log], clipTo: june)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 2)
        #expect(lines[1].hasSuffix(",7200,"))
    }

    @Test("clipTo 範囲と重ならないログは除外される")
    func excludesNonOverlapping() {
        let project = Project(name: "実装")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 5, 10, 9, 0),
                          endDate: TestSupport.date(2025, 5, 10, 10, 0))
        let june = TestSupport.date(2025, 6, 1, 0, 0)...TestSupport.date(2025, 7, 1, 0, 0)
        let csv = CSVExporter.makeCSV(logs: [log], clipTo: june)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 1) // ヘッダのみ
    }

    @Test("カンマを含む名前はクォートでエスケープされる")
    func escapesComma() {
        let project = Project(name: "A, B")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 9, 30))
        let csv = CSVExporter.makeCSV(logs: [log])
        #expect(csv.contains("\"A, B\""))
    }

    @Test("数式トリガで始まる名前はシングルクォートで無害化される")
    func neutralizesFormulaInjection() {
        let project = Project(name: "=1+1")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 9, 30))
        let csv = CSVExporter.makeCSV(logs: [log])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines[1].hasPrefix("'=1+1,"))
    }

    @Test("notes はセミコロン結合で出力される")
    func emitsNotes() {
        let project = Project(name: "実装")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 10, 0),
                          notes: ["設計", "レビュー"])
        let csv = CSVExporter.makeCSV(logs: [log])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines[1].hasSuffix(",3600,設計; レビュー"))
    }

    @Test("notes 内の特殊文字はエスケープされる")
    func escapesNotesWithSpecialChars() {
        let project = Project(name: "X")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 9, 30),
                          notes: ["=危険な数式"])
        let csv = CSVExporter.makeCSV(logs: [log])
        #expect(csv.contains("'=危険な数式"))
    }

    @Test("数式トリガかつカンマを含む名前は無害化後にクォートされる")
    func neutralizesAndQuotesFormulaWithComma() {
        let project = Project(name: "@SUM(A1,A2)")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 9, 30))
        let csv = CSVExporter.makeCSV(logs: [log])
        // 先頭にシングルクォートを付与し、カンマを含むため全体を CSV クォートで囲む。
        #expect(csv.contains("\"'@SUM(A1,A2)\""))
    }
}
