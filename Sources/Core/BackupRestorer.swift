import Foundation
import SwiftData

/// `BackupSnapshot` の内容でアプリのデータと設定を全置換する。
///
/// マージは行わない。既存レコードをすべて削除してから投入する。
@MainActor
enum BackupRestorer {
    /// 全削除 → 投入 → 設定反映の順に復元する。
    ///
    /// 呼び出し前に計測を停止しておくこと（削除されたログへの参照が残るため）。
    static func restore(
        _ snapshot: BackupSnapshot,
        into context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws {
        try deleteAll(in: context)
        try insert(snapshot, into: context)
        apply(snapshot.settings, to: defaults)
    }

    /// 既存データを全削除する。
    ///
    /// バッチ削除は関係制約に抵触するため使わない。多対多 `WorkNote.projects` の逆関連を
    /// 解除して保存してから WorkNote を消し、さらに保存してから Project を消す。
    /// この順序を崩すと SwiftData がトラップする。
    static func deleteAll(in context: ModelContext) throws {
        let workNotes = try context.fetch(FetchDescriptor<WorkNote>())
        for note in workNotes {
            note.projects = []
        }
        try context.save()
        for note in workNotes {
            context.delete(note)
        }
        try context.save()

        for session in try context.fetch(FetchDescriptor<ActiveSession>()) {
            context.delete(session)
        }
        for log in try context.fetch(FetchDescriptor<TimeLog>()) {
            context.delete(log)
        }
        for project in try context.fetch(FetchDescriptor<Project>()) {
            context.delete(project)
        }
        try context.save()
    }

    private static func insert(_ snapshot: BackupSnapshot, into context: ModelContext) throws {
        var projectsByID: [UUID: Project] = [:]
        for record in snapshot.projects {
            let project = Project(name: record.name, colorHex: record.colorHex, sortOrder: record.sortOrder)
            // init が採番した値を、バックアップ時点の同一性に戻す。
            project.id = record.id
            project.createdAt = record.createdAt
            context.insert(project)
            projectsByID[record.id] = project
        }

        for record in snapshot.workNotes {
            let projects = record.projectIDs.compactMap { id -> Project? in
                guard let project = projectsByID[id] else {
                    logMissingProject(id, context: "作業内容「\(record.text)」")
                    return nil
                }
                return project
            }
            // text の正規化規則は init（WorkNoteRenaming.key）に任せる。
            let note = WorkNote(text: record.text, projects: projects)
            note.id = record.id
            context.insert(note)
        }

        for record in snapshot.timeLogs {
            var project: Project?
            if let projectID = record.projectID {
                project = projectsByID[projectID]
                if project == nil {
                    logMissingProject(projectID, context: "計測ログ \(record.id.uuidString)")
                }
            }
            let log = TimeLog(
                project: project, startDate: record.startDate,
                endDate: record.endDate, notes: record.notes
            )
            log.id = record.id
            context.insert(log)
        }

        for record in snapshot.activeSessions {
            let session = ActiveSession(startDate: record.startDate, endDate: record.endDate)
            session.id = record.id
            context.insert(session)
        }

        try context.save()
    }

    /// 参照先が見つからなかったプロジェクトを記録する。
    /// 1 件の不整合で復元全体を失敗させず、該当の参照だけ落として続行する。
    private static func logMissingProject(_ id: UUID, context description: String) {
        AppLog.persistence.warning(
            """
            バックアップの復元: \(description, privacy: .public) が参照するプロジェクト \
            \(id.uuidString, privacy: .public) は見つかりませんでした
            """
        )
    }

    /// 設定を反映する。値が不正なキーは既定値へフォールバックする。
    private static func apply(_ settings: BackupSnapshot.SettingsRecord, to defaults: UserDefaults) {
        if let value = settings.idleDetectionEnabled {
            defaults.set(value, forKey: AppSettingsKey.idleDetectionEnabled)
        }
        if let value = settings.idleThresholdMinutes {
            defaults.set(max(0, value), forKey: AppSettingsKey.idleThresholdMinutes)
        }
        if let value = settings.idleAlertEnabled {
            defaults.set(value, forKey: AppSettingsKey.idleAlertEnabled)
        }
        if let value = settings.allowConcurrentTracking {
            defaults.set(value, forKey: AppSettingsKey.allowConcurrentTracking)
        }
        if let value = settings.timelineSnapMinutes {
            let snap = [5, 10, 15, 30].contains(value) ? value : AppSettingsDefault.timelineSnapMinutes
            defaults.set(snap, forKey: AppSettingsKey.timelineSnapMinutes)
        }
        if let value = settings.promptForWorkNoteOnStop {
            defaults.set(value, forKey: AppSettingsKey.promptForWorkNoteOnStop)
        }
        if let value = settings.dimBlocksWithoutNotes {
            defaults.set(value, forKey: AppSettingsKey.dimBlocksWithoutNotes)
        }
        if let value = settings.displayLanguage {
            let language = AppLanguage(rawValue: value) ?? AppSettingsDefault.displayLanguage
            defaults.set(language.rawValue, forKey: AppSettingsKey.displayLanguage)
        }
    }
}
