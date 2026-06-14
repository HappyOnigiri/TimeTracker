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
        #expect(lines[0] == "project,start,end,duration_seconds")
        #expect(lines.count == 2)
        #expect(lines[1].hasPrefix("実装,"))
        #expect(lines[1].hasSuffix(",3600"))
    }

    @Test("計測中ログは除外される")
    func excludesRunningLogs() {
        let project = Project(name: "X")
        let running = TimeLog(project: project, startDate: TestSupport.date(2025, 1, 10, 9, 0), endDate: nil)
        let csv = CSVExporter.makeCSV(logs: [running])
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
}
