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

    // MARK: - noteTotals

    private var noteRange: ClosedRange<Date> {
        TestSupport.date(2025, 1, 1)...TestSupport.date(2025, 2, 1)
    }

    @Test("複数 note を持つログは均等割りされる")
    func noteTotalsSplitsEvenly() {
        let project = Project(name: "A")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 10, 0),
                          notes: ["設計", "レビュー"])
        let totals = ReportAggregator.noteTotals(logs: [log], in: noteRange, calendar: TestSupport.utcCalendar)
        #expect(totals.count == 2)
        let byNote = Dictionary(uniqueKeysWithValues: totals.map { ($0.note, $0.seconds) })
        #expect(byNote["設計"] == 1800)
        #expect(byNote["レビュー"] == 1800)
    }

    @Test("notes が空のログは「(未分類)」に集約される")
    func noteTotalsGroupsEmptyNotesAsUncategorized() {
        let project = Project(name: "A")
        let log1 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 10, 9, 0),
                           endDate: TestSupport.date(2025, 1, 10, 10, 0),
                           notes: [])
        let log2 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 11, 9, 0),
                           endDate: TestSupport.date(2025, 1, 11, 10, 0),
                           notes: [])
        let totals = ReportAggregator.noteTotals(logs: [log1, log2], in: noteRange, calendar: TestSupport.utcCalendar)
        #expect(totals.count == 1)
        #expect(totals[0].note == nil)
        #expect(totals[0].seconds == 7200)
    }

    @Test("同一ログ内の重複 note は dedup される")
    func noteTotalsDedupsSameNoteInLog() {
        let project = Project(name: "A")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 10, 0),
                          notes: ["設計", "設計"])
        let totals = ReportAggregator.noteTotals(logs: [log], in: noteRange, calendar: TestSupport.utcCalendar)
        #expect(totals.count == 1)
        #expect(totals[0].note == "設計")
        #expect(totals[0].seconds == 3600)
    }

    @Test("noteTotals は期間クリップを適用する")
    func noteTotalsClipsToRange() {
        let project = Project(name: "A")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 9, 23, 0),
                          endDate: TestSupport.date(2025, 1, 10, 1, 0),
                          notes: ["実装"])
        let narrowRange = TestSupport.date(2025, 1, 10)...TestSupport.date(2025, 1, 11)
        let totals = ReportAggregator.noteTotals(logs: [log], in: narrowRange, calendar: TestSupport.utcCalendar)
        #expect(totals[0].seconds == 3600)
    }

    // MARK: - dailyWorkSummaries

    @Test("日付別集計は同じ日のログを合算し、作業内容を出現順に集める")
    func dailyWorkSummariesSumsAndCollectsNotes() {
        let project = Project(name: "A")
        let log1 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 10, 9, 0),
                           endDate: TestSupport.date(2025, 1, 10, 10, 0),
                           notes: ["設計"])
        let log2 = TimeLog(project: project,
                           startDate: TestSupport.date(2025, 1, 10, 13, 0),
                           endDate: TestSupport.date(2025, 1, 10, 14, 30),
                           notes: ["実装", "設計"])
        let summaries = ReportAggregator.dailyWorkSummaries(
            logs: [log2, log1],
            in: TestSupport.date(2025, 1, 10)...TestSupport.date(2025, 1, 11),
            calendar: TestSupport.utcCalendar)
        #expect(summaries.count == 1)
        #expect(summaries[0].day == TestSupport.date(2025, 1, 10))
        #expect(summaries[0].seconds == 9000) // 1h + 1.5h
        #expect(summaries[0].notes == ["設計", "実装"]) // 開始時刻順・重複除去
    }

    @Test("日付別集計は日跨ぎログを日付境界で分割し、双方の日に作業内容を残す")
    func dailyWorkSummariesSplitsAtMidnight() {
        let project = Project(name: "A")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 11, 23, 30),
                          endDate: TestSupport.date(2025, 1, 12, 0, 30),
                          notes: ["夜間対応"])
        let summaries = ReportAggregator.dailyWorkSummaries(
            logs: [log],
            in: TestSupport.date(2025, 1, 11)...TestSupport.date(2025, 1, 13),
            calendar: TestSupport.utcCalendar)
        #expect(summaries.count == 2)
        #expect(summaries[0].day == TestSupport.date(2025, 1, 11))
        #expect(summaries[0].seconds == 1800)
        #expect(summaries[0].notes == ["夜間対応"])
        #expect(summaries[1].day == TestSupport.date(2025, 1, 12))
        #expect(summaries[1].seconds == 1800)
        #expect(summaries[1].notes == ["夜間対応"])
    }

    @Test("日付別集計は空の作業内容を除き、プロジェクト未設定のログも含める")
    func dailyWorkSummariesIgnoresEmptyNotesAndKeepsOrphanLogs() {
        let log = TimeLog(project: nil,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 10, 0),
                          notes: ["  ", ""])
        let summaries = ReportAggregator.dailyWorkSummaries(
            logs: [log],
            in: TestSupport.date(2025, 1, 10)...TestSupport.date(2025, 1, 11),
            calendar: TestSupport.utcCalendar)
        #expect(summaries.count == 1)
        #expect(summaries[0].seconds == 3600)
        #expect(summaries[0].notes.isEmpty)
    }

    @Test("日付別集計は JST カレンダーで日付境界を判定する")
    func dailyWorkSummariesUsesJSTBoundary() {
        let project = Project(name: "A")
        // UTC 1/9 16:00〜17:00 は JST では 1/10 01:00〜02:00。
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 9, 16, 0),
                          endDate: TestSupport.date(2025, 1, 9, 17, 0))
        let jstDay = Calendar.jst.startOfDay(for: TestSupport.date(2025, 1, 9, 16, 0))
        let nextJSTDay = Calendar.jst.date(byAdding: .day, value: 1, to: jstDay)!
        let summaries = ReportAggregator.dailyWorkSummaries(
            logs: [log], in: jstDay...nextJSTDay, calendar: .jst)
        #expect(summaries.count == 1)
        #expect(summaries[0].day == jstDay)
        #expect(summaries[0].seconds == 3600)
    }

    @Test("日付別集計は稼働のない日も 0 秒で含め、期間の全日を網羅する")
    func dailyWorkSummariesIncludesEmptyDays() {
        let project = Project(name: "A")
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: TestSupport.date(2025, 1, 10, 10, 0))
        // range は 1/1 0:00〜2/1 0:00。2/1 は 0:00 ちょうどなので含めず 31 日。
        let summaries = ReportAggregator.dailyWorkSummaries(
            logs: [log], in: range, calendar: TestSupport.utcCalendar)
        #expect(summaries.count == 31)
        #expect(summaries.first?.day == TestSupport.date(2025, 1, 1))
        #expect(summaries.last?.day == TestSupport.date(2025, 1, 31))
        #expect(summaries.first?.seconds == 0)
        #expect(summaries.first?.notes.isEmpty == true)
        let tenth = summaries.first { $0.day == TestSupport.date(2025, 1, 10) }
        #expect(tenth?.seconds == 3600)
    }
}
