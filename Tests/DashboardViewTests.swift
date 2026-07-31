import Foundation
import Testing
@testable import TimeTracker

struct DashboardViewTests {
    @Test("日付別 CSV の範囲は海外の選択月でも JST の月初から月末までを含む")
    func dailyWorkRangeUsesJSTMonthBoundariesOutsideJapan() {
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let selectedMonth = losAngeles.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let range = DashboardView.dailyWorkRange(
            for: selectedMonth,
            selectedMonthCalendar: losAngeles)

        let calendar = Calendar.jst
        let januaryStart = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let februaryStart = calendar.date(from: DateComponents(year: 2025, month: 2, day: 1))!
        #expect(range.lowerBound == januaryStart)
        #expect(range.upperBound == februaryStart)

        let project = Project(name: "A")
        let firstDayLog = TimeLog(
            project: project,
            startDate: calendar.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 0, minute: 30))!,
            endDate: calendar.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 1, minute: 30))!)
        let lastDayLog = TimeLog(
            project: project,
            startDate: calendar.date(from: DateComponents(year: 2025, month: 1, day: 31, hour: 22, minute: 30))!,
            endDate: calendar.date(from: DateComponents(year: 2025, month: 1, day: 31, hour: 23, minute: 30))!)

        let summaries = ReportAggregator.dailyWorkSummaries(
            logs: [firstDayLog, lastDayLog], in: range, calendar: calendar)
        #expect(summaries.count == 31)
        #expect(summaries.first?.seconds == 3600)
        #expect(summaries.last?.seconds == 3600)
    }
}
