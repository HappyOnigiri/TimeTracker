import Foundation
import Testing
@testable import TimeTracker

struct ReportAggregatorTests {
    // @Model は ModelContainer に挿入しなくても生成・プロパティ参照が可能なため、
    // 集計ロジックの検証では Container を使わない（並列テスト時の SwiftData 競合も回避）。
    private func makeLogs() -> [TimeLog] {
        let project = Project(name: "A", colorHex: "#FF0000")
        // 1.5 時間
        let log1 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 10, 9, 0),
                           endDate: TestSupport.date(2025, 1, 10, 10, 30))
        // 日跨ぎ: 各日 30 分
        let log2 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 11, 23, 30),
                           endDate: TestSupport.date(2025, 1, 12, 0, 30))
        return [log1, log2]
    }

    private var range: ClosedRange<Date> {
        TestSupport.date(2025, 1, 1)...TestSupport.date(2025, 2, 1)
    }

    @Test("プロジェクト合計は全ログを合算する")
    func projectTotalsSumsAllLogs() {
        let totals = ReportAggregator.projectTotals(logs: makeLogs(), in: range, calendar: TestSupport.utcCalendar)
        #expect(totals.count == 1)
        #expect(totals[0].seconds == 9000) // 1.5h + 1h
        #expect(totals[0].name == "A")
    }

    @Test("日次集計は日付境界で分割する")
    func dailyDurationsSplitsAtMidnight() {
        let daily = ReportAggregator.dailyDurations(logs: makeLogs(), in: range, calendar: TestSupport.utcCalendar)
        let byDay = Dictionary(uniqueKeysWithValues: daily.map {
            (TestSupport.utcCalendar.startOfDay(for: $0.day), $0.seconds)
        })
        #expect(byDay[TestSupport.date(2025, 1, 10)] == 5400) // 1.5h
        #expect(byDay[TestSupport.date(2025, 1, 11)] == 1800) // 30m
        #expect(byDay[TestSupport.date(2025, 1, 12)] == 1800) // 30m
    }

    @Test("期間外のログはクリップされる")
    func clipsOutsideRange() {
        let project = Project(name: "B")
        // 範囲は 1/10 のみ。ログは 1/9 23:00〜1/10 01:00（範囲内は 1 時間）
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 9, 23, 0),
                          endDate: TestSupport.date(2025, 1, 10, 1, 0))
        let narrowRange = TestSupport.date(2025, 1, 10)...TestSupport.date(2025, 1, 11)
        let totals = ReportAggregator.projectTotals(logs: [log], in: narrowRange, calendar: TestSupport.utcCalendar)
        #expect(totals[0].seconds == 3600)
    }
}
