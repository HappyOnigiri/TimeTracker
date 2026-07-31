import SwiftData
import Testing
@testable import TimeTracker

@MainActor
struct ReadmeScreenshotTests {
    @Test("サンプルデータは前月分の完了済み記録を生成する")
    func sampleDataIsReadyForScreenshots() throws {
        let context = try TestSupport.makeContext()
        let now = TestSupport.date(2026, 8, 1, 12)
        try ScreenshotSampleData.replaceAll(
            in: context,
            now: now,
            calendar: TestSupport.utcCalendar
        )

        let projects = try context.fetch(FetchDescriptor<Project>())
        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        let sessions = try context.fetch(FetchDescriptor<ActiveSession>())

        #expect(projects.count == ScreenshotSampleData.projects.count)
        #expect(logs.count == ScreenshotSampleData.entries.count)
        #expect(sessions.count == ScreenshotSampleData.entries.count)
        #expect(logs.allSatisfy { $0.endDate != nil })
        #expect(logs.allSatisfy { TestSupport.utcCalendar.component(.month, from: $0.startDate) == 7 })
    }
}
