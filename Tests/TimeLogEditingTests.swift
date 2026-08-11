import SwiftData
import Testing
@testable import TimeTracker

@Suite(.serialized)
@MainActor
struct TimeLogEditingTests {
    @Test("追加で作業内容を選択プロジェクトへ関連付ける")
    func addRecordsUsage() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let project = Project(name: "A")
        context.insert(project)

        TimeLogEditing.add(
            project: project,
            start: TestSupport.date(2025, 1, 1, 9),
            end: TestSupport.date(2025, 1, 1, 10),
            notes: [" 実装 "],
            in: context
        )

        let item = try #require(context.fetch(FetchDescriptor<WorkNote>()).first)
        #expect(item.text == "実装")
        #expect(item.projects.map(\.id) == [project.id])
    }

    @Test("更新で新プロジェクトを追加し旧関連を維持する")
    func updateAccumulatesProject() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        context.insert(projectA)
        context.insert(projectB)
        TimeLogEditing.add(
            project: projectA,
            start: TestSupport.date(2025, 1, 1, 9),
            end: TestSupport.date(2025, 1, 1, 10),
            notes: ["実装"],
            in: context
        )
        let log = try #require(context.fetch(FetchDescriptor<TimeLog>()).first)

        TimeLogEditing.update(
            log,
            project: projectB,
            start: log.startDate,
            end: try #require(log.endDate),
            notes: log.notes,
            in: context
        )

        let item = try #require(context.fetch(FetchDescriptor<WorkNote>()).first)
        #expect(Set(item.projects.map(\.id)) == [projectA.id, projectB.id])
    }

    @Test("複製で不足している関連を補完する")
    func duplicateRecordsUsage() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let project = Project(name: "A")
        let log = TimeLog(
            project: project,
            startDate: TestSupport.date(2025, 1, 1, 9),
            endDate: TestSupport.date(2025, 1, 1, 10),
            notes: ["実装"]
        )
        context.insert(project)
        context.insert(log)
        try context.save()

        TimeLogEditing.duplicate(log, in: context)

        #expect(try context.fetch(FetchDescriptor<TimeLog>()).count == 2)
        let item = try #require(context.fetch(FetchDescriptor<WorkNote>()).first)
        #expect(item.projects.map(\.id) == [project.id])
    }

    @Test("ログ削除ではカタログと関連を削除しない")
    func deletePreservesCatalog() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let project = Project(name: "A")
        context.insert(project)
        TimeLogEditing.add(
            project: project,
            start: TestSupport.date(2025, 1, 1, 9),
            end: TestSupport.date(2025, 1, 1, 10),
            notes: ["実装"],
            in: context
        )
        let log = try #require(context.fetch(FetchDescriptor<TimeLog>()).first)

        TimeLogEditing.delete(log, in: context)

        #expect(try context.fetch(FetchDescriptor<TimeLog>()).isEmpty)
        let item = try #require(context.fetch(FetchDescriptor<WorkNote>()).first)
        #expect(item.text == "実装")
        #expect(item.projects.map(\.id) == [project.id])
    }
}
