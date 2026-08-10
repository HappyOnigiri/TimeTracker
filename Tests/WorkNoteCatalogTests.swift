import SwiftData
import Testing
@testable import TimeTracker

@Suite(.serialized)
@MainActor
struct WorkNoteCatalogTests {
    @Test("既存ログを正規化して作業内容と関連プロジェクトを構築する")
    func bootstrapsFromLogs() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        context.insert(projectA)
        context.insert(projectB)
        context.insert(makeLog(project: projectA, day: 1, notes: [" 設計 "]))
        context.insert(makeLog(project: projectB, day: 2, notes: ["設計", "実装"]))
        context.insert(makeLog(project: nil, day: 3, notes: ["未分類"]))
        try context.save()

        try WorkNoteCatalog.bootstrap(in: context)

        let catalog = try context.fetch(FetchDescriptor<WorkNote>())
        #expect(Set(catalog.map(\.text)) == ["設計", "実装", "未分類"])
        let design = try #require(catalog.first { $0.text == "設計" })
        #expect(Set(design.projects.map(\.id)) == [projectA.id, projectB.id])
        #expect(catalog.first { $0.text == "未分類" }?.projects.isEmpty == true)
    }

    @Test("複数回の初期化で重複せず既存項目の手動関連を上書きしない")
    func bootstrapIsIdempotentAndPreservesExistingRelations() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        let existing = WorkNote(text: "設計", projects: [projectB])
        context.insert(projectA)
        context.insert(projectB)
        context.insert(existing)
        context.insert(makeLog(project: projectA, day: 1, notes: ["設計"]))
        try context.save()

        try WorkNoteCatalog.bootstrap(in: context)
        try WorkNoteCatalog.bootstrap(in: context)

        let catalog = try context.fetch(FetchDescriptor<WorkNote>())
        #expect(catalog.count == 1)
        #expect(Set(catalog[0].projects.map(\.id)) == [projectB.id])
    }

    @Test("利用時に新規作成し別プロジェクトでの利用を関連へ累積する")
    func recordsUsageCumulatively() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        context.insert(projectA)
        context.insert(projectB)

        WorkNoteCatalog.recordUsage([" 実装 "], for: projectA, in: context)
        try context.save()
        WorkNoteCatalog.recordUsage(["実装"], for: projectB, in: context)
        try context.save()

        let catalog = try context.fetch(FetchDescriptor<WorkNote>())
        #expect(catalog.count == 1)
        #expect(catalog[0].text == "実装")
        #expect(Set(catalog[0].projects.map(\.id)) == [projectA.id, projectB.id])
    }

    @Test("関連プロジェクトを0件へ更新できる")
    func clearsProjects() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let project = Project(name: "A")
        let item = WorkNote(text: "実装", projects: [project])
        context.insert(project)
        context.insert(item)
        try context.save()

        let result = try WorkNoteCatalog.update(id: item.id, text: "実装", projectIDs: [], in: context)

        #expect(result == .updated(affectedLogs: 0))
        #expect(item.projects.isEmpty)
    }

    @Test("通常リネームで全ログとカタログを更新する")
    func renamesCatalogAndLogs() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let project = Project(name: "A")
        let item = WorkNote(text: "設計", projects: [project])
        context.insert(project)
        context.insert(item)
        let logA = makeLog(project: project, day: 1, notes: ["設計", "調査"])
        let logB = makeLog(project: project, day: 2, notes: ["設計"])
        context.insert(logA)
        context.insert(logB)
        try context.save()

        let result = try WorkNoteCatalog.update(
            id: item.id, text: " 基本設計 ", projectIDs: [project.id], in: context
        )

        #expect(result == .updated(affectedLogs: 2))
        #expect(item.text == "基本設計")
        #expect(logA.notes == ["基本設計", "調査"])
        #expect(logB.notes == ["基本設計"])
    }

    @Test("同名統合でログ内重複を除き関連を和集合にして元項目を削除する")
    func mergesIntoExistingItem() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        let source = WorkNote(text: "設計", projects: [projectA])
        let destination = WorkNote(text: "実装", projects: [projectB])
        context.insert(projectA)
        context.insert(projectB)
        context.insert(source)
        context.insert(destination)
        let log = makeLog(project: projectA, day: 1, notes: ["設計", "実装"])
        context.insert(log)
        try context.save()

        let result = try WorkNoteCatalog.update(
            id: source.id, text: "実装", projectIDs: [projectA.id], in: context
        )

        #expect(result == .merged(affectedLogs: 1))
        #expect(log.notes == ["実装"])
        let catalog = try context.fetch(FetchDescriptor<WorkNote>())
        #expect(catalog.count == 1)
        #expect(catalog[0].id == destination.id)
        #expect(Set(catalog[0].projects.map(\.id)) == [projectA.id, projectB.id])
    }

    @Test("プロジェクト削除後も作業内容は関連0件で残る")
    func deletingProjectNullifiesRelationship() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let project = Project(name: "A")
        let item = WorkNote(text: "実装", projects: [project])
        context.insert(project)
        context.insert(item)
        try context.save()

        context.delete(project)
        try context.save()

        let catalog = try context.fetch(FetchDescriptor<WorkNote>())
        #expect(catalog.count == 1)
        #expect(catalog[0].projects.isEmpty)
    }

    private func makeLog(project: Project?, day: Int, notes: [String]) -> TimeLog {
        TimeLog(
            project: project,
            startDate: TestSupport.date(2025, 1, day, 9),
            endDate: TestSupport.date(2025, 1, day, 10),
            notes: notes
        )
    }
}
