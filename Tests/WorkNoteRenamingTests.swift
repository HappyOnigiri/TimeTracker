import Foundation
import SwiftData
import Testing
@testable import TimeTracker

// TestSupport.makeContext() は共有 Container を使い回すため、直列実行が前提。
@Suite(.serialized)
@MainActor
struct WorkNoteRenamingTests {
    // MARK: - renamed（純粋関数）

    @Test("完全一致するタグが新しい文言に置き換わる")
    func replacesExactMatch() {
        let result = WorkNoteRenaming.renamed(notes: ["設計", "実装"], from: "設計", to: "基本設計")
        #expect(result == ["基本設計", "実装"])
    }

    @Test("一致するタグがなければ nil を返す")
    func returnsNilWhenNoMatch() {
        #expect(WorkNoteRenaming.renamed(notes: ["設計", "実装"], from: "レビュー", to: "コードレビュー") == nil)
    }

    @Test("部分一致するだけのタグは置換されない")
    func doesNotReplacePartialMatch() {
        #expect(WorkNoteRenaming.renamed(notes: ["基本設計"], from: "設計", to: "詳細設計") == nil)
    }

    @Test("置換で重複したタグは最初の出現位置を残してマージされる")
    func mergesDuplicatesAfterRename() {
        let result = WorkNoteRenaming.renamed(notes: ["設計", "実装"], from: "設計", to: "実装")
        #expect(result == ["実装"])
    }

    @Test("既存タグと重複する場合も順序は最初の出現位置を維持する")
    func keepsFirstOccurrencePosition() {
        let result = WorkNoteRenaming.renamed(notes: ["実装", "テスト", "設計"], from: "設計", to: "実装")
        #expect(result == ["実装", "テスト"])
    }

    @Test("正規化後に old と new が同一なら nil を返す")
    func returnsNilWhenUnchangedAfterTrimming() {
        #expect(WorkNoteRenaming.renamed(notes: ["設計"], from: "設計", to: "  設計  ") == nil)
    }

    @Test("old と new は前後の空白を除いて比較し、除いた形で保存される")
    func trimsArguments() {
        let result = WorkNoteRenaming.renamed(notes: ["設計"], from: " 設計 ", to: " 基本設計 ")
        #expect(result == ["基本設計"])
    }

    @Test("new が空白のみなら nil を返す")
    func returnsNilForBlankNew() {
        #expect(WorkNoteRenaming.renamed(notes: ["設計"], from: "設計", to: "   ") == nil)
    }

    @Test("対象以外のタグは順序と内容が保たれる")
    func preservesOtherNotes() {
        let result = WorkNoteRenaming.renamed(notes: ["調査", "設計", "実装"], from: "設計", to: "基本設計")
        #expect(result == ["調査", "基本設計", "実装"])
    }

    @Test("前後の空白だけが違う重複も 1 つにまとめられる")
    func mergesDuplicatesIgnoringSurroundingWhitespace() {
        let result = WorkNoteRenaming.renamed(notes: [" 実装 ", "設計"], from: "設計", to: "実装")
        #expect(result == [" 実装 "])
    }

    // MARK: - matches

    @Test("matches は完全一致するタグだけを検出する")
    func matchesExactTagOnly() {
        #expect(WorkNoteRenaming.matches(notes: [" 設計 ", "実装"], tag: "設計"))
        #expect(!WorkNoteRenaming.matches(notes: ["基本設計"], tag: "設計"))
        #expect(!WorkNoteRenaming.matches(notes: ["設計"], tag: "   "))
    }

    // MARK: - rename（ModelContext を伴う）

    @Test("複数プロジェクトにまたがるタグがすべて置換され、変更件数が返る")
    func renamesAcrossProjects() throws {
        let context = try TestSupport.makeContext()
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        context.insert(projectA)
        context.insert(projectB)
        let log1 = makeLog(project: projectA, day: 10, notes: ["設計", "調査"], in: context)
        let log2 = makeLog(project: projectB, day: 11, notes: ["設計"], in: context)
        let log3 = makeLog(project: projectA, day: 12, notes: ["実装"], in: context)
        try context.save()

        let count = WorkNoteRenaming.rename(from: "設計", to: "基本設計", in: [log1, log2, log3], context: context)

        #expect(count == 2)
        #expect(log1.notes == ["基本設計", "調査"])
        #expect(log2.notes == ["基本設計"])
        #expect(log3.notes == ["実装"])
    }

    @Test("対象タグが存在しない場合は 0 を返し、どのログも変更されない")
    func returnsZeroWhenNoTarget() throws {
        let context = try TestSupport.makeContext()
        let project = Project(name: "A")
        context.insert(project)
        let log = makeLog(project: project, day: 10, notes: ["実装"], in: context)
        try context.save()

        let count = WorkNoteRenaming.rename(from: "設計", to: "基本設計", in: [log], context: context)

        #expect(count == 0)
        #expect(log.notes == ["実装"])
    }

    @Test("計測中（endDate が nil）のログも置換対象になる")
    func renamesRunningLog() throws {
        let context = try TestSupport.makeContext()
        let project = Project(name: "A")
        context.insert(project)
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, 10, 9, 0),
                          endDate: nil,
                          notes: ["設計"])
        context.insert(log)
        try context.save()

        let count = WorkNoteRenaming.rename(from: "設計", to: "基本設計", in: [log], context: context)

        #expect(count == 1)
        #expect(log.notes == ["基本設計"])
    }

    private func makeLog(project: Project, day: Int, notes: [String], in context: ModelContext) -> TimeLog {
        let log = TimeLog(project: project,
                          startDate: TestSupport.date(2025, 1, day, 9, 0),
                          endDate: TestSupport.date(2025, 1, day, 10, 0),
                          notes: notes)
        context.insert(log)
        return log
    }
}
