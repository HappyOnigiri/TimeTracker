import Foundation
import SwiftData

/// 作業内容カタログの移行・利用記録・管理画面からの更新をまとめる。
enum WorkNoteCatalog {
    enum UpdateResult: Equatable {
        case updated(affectedLogs: Int)
        case merged(affectedLogs: Int)
    }

    enum CatalogError: LocalizedError {
        case emptyText
        case targetMissing

        var errorDescription: String? {
            switch self {
            case .emptyText:
                L10n.string("作業内容を入力してください", locale: .current)
            case .targetMissing:
                L10n.string("対象の作業内容が見つかりません", locale: .current)
            }
        }
    }

    /// 既存ログから、まだカタログにない作業内容だけを構築する。
    /// 既存項目の関連はユーザー編集済みとみなし変更しない。
    static func bootstrap(in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<WorkNote>())
        var existingKeys = Set(existing.map { WorkNoteRenaming.key($0.text) })
        let logs = try context.fetch(FetchDescriptor<TimeLog>())

        var projectsByText: [String: [UUID: Project]] = [:]
        for log in logs {
            for rawNote in log.notes {
                let text = WorkNoteRenaming.key(rawNote)
                guard !text.isEmpty, !existingKeys.contains(text) else { continue }
                if let project = log.project {
                    projectsByText[text, default: [:]][project.id] = project
                } else if projectsByText[text] == nil {
                    projectsByText[text] = [:]
                }
            }
        }

        guard !projectsByText.isEmpty else { return }
        for text in projectsByText.keys.sorted() {
            guard existingKeys.insert(text).inserted else { continue }
            let projects = Array(projectsByText[text, default: [:]].values)
            context.insert(WorkNote(text: text, projects: projects))
        }
        try context.save()
    }

    /// 保存された作業内容を作成または取得し、今回使ったプロジェクトを関連へ累積する。
    /// 呼び出し側がログと同じ `ModelContext.save()` で確定する。
    static func recordUsage(_ notes: [String], for projects: [Project], in context: ModelContext) throws {
        let normalized = normalizedNotes(notes)
        guard !normalized.isEmpty else { return }

        let catalog = try context.fetch(FetchDescriptor<WorkNote>())
        var byText: [String: WorkNote] = [:]
        for item in catalog where byText[WorkNoteRenaming.key(item.text)] == nil {
            byText[WorkNoteRenaming.key(item.text)] = item
        }

        for text in normalized {
            let item: WorkNote
            if let existing = byText[text] {
                item = existing
            } else {
                item = WorkNote(text: text)
                context.insert(item)
                byText[text] = item
            }
            appendMissingProjects(projects, to: item)
        }
    }

    static func recordUsage(_ notes: [String], for project: Project?, in context: ModelContext) throws {
        try recordUsage(notes, for: project.map { [$0] } ?? [], in: context)
    }

    /// 管理画面の編集内容をログとカタログへ反映し、1回の save で確定する。
    @discardableResult
    static func update(
        id: UUID,
        text rawText: String,
        projectIDs: Set<UUID>,
        in context: ModelContext
    ) throws -> UpdateResult {
        let text = WorkNoteRenaming.key(rawText)
        guard !text.isEmpty else { throw CatalogError.emptyText }

        let catalog = try context.fetch(FetchDescriptor<WorkNote>())
        guard let target = catalog.first(where: { $0.id == id }) else {
            throw CatalogError.targetMissing
        }
        let projects = try context.fetch(FetchDescriptor<Project>())
            .filter { projectIDs.contains($0.id) }
        let oldText = WorkNoteRenaming.key(target.text)

        if oldText == text {
            target.text = text
            target.projects = projects
            try saveOrRollback(context)
            return .updated(affectedLogs: 0)
        }

        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        var affectedLogs = 0
        for log in logs {
            guard let renamed = WorkNoteRenaming.renamed(notes: log.notes, from: oldText, to: text) else {
                continue
            }
            log.notes = renamed
            affectedLogs += 1
        }

        if let destination = catalog.first(where: {
            $0.id != target.id && WorkNoteRenaming.key($0.text) == text
        }) {
            appendMissingProjects(projects, to: destination)
            context.delete(target)
            try saveOrRollback(context)
            return .merged(affectedLogs: affectedLogs)
        }

        target.text = text
        target.projects = projects
        try saveOrRollback(context)
        return .updated(affectedLogs: affectedLogs)
    }

    static func normalizedNotes(_ notes: [String]) -> [String] {
        var seen = Set<String>()
        return notes.compactMap { note in
            let text = WorkNoteRenaming.key(note)
            guard !text.isEmpty, seen.insert(text).inserted else { return nil }
            return text
        }
    }

    private static func appendMissingProjects(_ projects: [Project], to note: WorkNote) {
        var projectIDs = Set(note.projects.map(\.id))
        for project in projects where projectIDs.insert(project.id).inserted {
            note.projects.append(project)
        }
    }

    private static func saveOrRollback(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
