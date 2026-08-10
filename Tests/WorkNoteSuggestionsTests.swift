import Foundation
import Testing
@testable import TimeTracker

struct WorkNoteSuggestionsTests {
    private let now = TestSupport.date(2025, 3, 31, 12, 0)

    @Test("現在プロジェクトに関連する直近1か月以内の候補だけを返す")
    func filtersByProjectAndRecency() {
        let current = Project(name: "A")
        let other = Project(name: "B")
        let recent = WorkNote(text: "最近", projects: [current])
        let old = WorkNote(text: "古い", projects: [current])
        let unrelated = WorkNote(text: "無関係", projects: [other])
        let logs = [
            log(project: current, date: TestSupport.date(2025, 3, 20), note: "最近"),
            log(project: current, date: TestSupport.date(2025, 2, 20), note: "古い"),
            log(project: other, date: TestSupport.date(2025, 3, 25), note: "無関係")
        ]

        let result = candidates([recent, old, unrelated], logs: logs, projectIDs: [current.id])

        #expect(result == ["最近"])
    }

    @Test("複数の現在プロジェクトのどれかに関連すれば表示する")
    func matchesAnyCurrentProject() {
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        let item = WorkNote(text: "共有", projects: [projectB])
        let logs = [log(project: projectB, date: TestSupport.date(2025, 3, 20), note: "共有")]

        let result = candidates([item], logs: logs, projectIDs: [projectA.id, projectB.id])

        #expect(result == ["共有"])
    }

    @Test("境界日時以前と利用ログのない候補を通常表示から除外する")
    func excludesBoundaryAndUnusedItems() {
        let project = Project(name: "A")
        let boundary = WorkNote(text: "境界", projects: [project])
        let unused = WorkNote(text: "未使用", projects: [project])
        let logs = [log(project: project, date: TestSupport.date(2025, 2, 28, 12, 0), note: "境界")]

        let result = candidates([boundary, unused], logs: logs, projectIDs: [project.id])

        #expect(result.isEmpty)
    }

    @Test("すべて表示は関連・利用日時・件数にかかわらず全候補を返す")
    func showAllReturnsEveryCatalogItem() {
        let project = Project(name: "A")
        let other = Project(name: "B")
        let items = (1...25).map { index in
            WorkNote(text: String(format: "候補%02d", index), projects: index == 1 ? [] : [other])
        }
        let logs = [log(project: other, date: TestSupport.date(2024, 1, 1), note: "候補02")]

        let result = candidates(items, logs: logs, projectIDs: [project.id], showAll: true)

        #expect(result.count == 25)
        #expect(result.first == "候補02")
        #expect(result.dropFirst().first == "候補01")
    }

    @Test("最終利用日時の降順、同日時は文言順、利用なしは末尾になる")
    func sortsByLatestUseThenText() {
        let project = Project(name: "A")
        let items = [
            WorkNote(text: "未使用B", projects: []),
            WorkNote(text: "同時B", projects: [project]),
            WorkNote(text: "最新", projects: [project]),
            WorkNote(text: "同時A", projects: [project]),
            WorkNote(text: "未使用A", projects: [])
        ]
        let logs = [
            log(project: project, date: TestSupport.date(2025, 3, 25), note: "最新"),
            log(project: project, date: TestSupport.date(2025, 3, 20), note: "同時A"),
            log(project: project, date: TestSupport.date(2025, 3, 20), note: "同時B")
        ]

        let result = candidates(items, logs: logs, projectIDs: [project.id], showAll: true)

        #expect(result == ["最新", "同時A", "同時B", "未使用A", "未使用B"])
    }

    @Test("endDate が nil のログは startDate を最終利用日時に使う")
    func usesStartDateForRunningLog() {
        let project = Project(name: "A")
        let running = WorkNote(text: "計測中", projects: [project])
        let finished = WorkNote(text: "完了", projects: [project])
        let logs = [
            TimeLog(project: project, startDate: TestSupport.date(2025, 3, 25), notes: ["計測中"]),
            log(project: project, date: TestSupport.date(2025, 3, 20), note: "完了")
        ]

        #expect(candidates([running, finished], logs: logs, projectIDs: [project.id]) == ["計測中", "完了"])
    }

    private func candidates(
        _ workNotes: [WorkNote],
        logs: [TimeLog],
        projectIDs: Set<UUID>,
        showAll: Bool = false
    ) -> [String] {
        WorkNoteSuggestions.candidates(
            from: workNotes,
            logs: logs,
            projectIDs: projectIDs,
            showAll: showAll,
            now: now,
            calendar: TestSupport.utcCalendar
        )
    }

    private func log(project: Project, date: Date, note: String) -> TimeLog {
        TimeLog(project: project, startDate: date.addingTimeInterval(-3600), endDate: date, notes: [note])
    }
}
