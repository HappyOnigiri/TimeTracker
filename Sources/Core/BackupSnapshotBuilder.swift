import Foundation
import SwiftData

/// SwiftData の全レコードと設定から `BackupSnapshot` を組み立てる。
///
/// 保存先は知らない。ファイル書き出しと将来の git バックアップで共通に使う。
@MainActor
enum BackupSnapshotBuilder {
    /// Info.plist を唯一の真実の源とするアプリのバージョン。
    /// 引数の既定値として使うため、MainActor から切り離す。
    nonisolated static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    /// 現在のデータからスナップショットを作る。
    ///
    /// `appVersion` / `exportedAt` / `defaults` は引数で受け取る。テストの決定性を保ち、
    /// `UserDefaults.standard` を暗黙に読みに行かないため。
    static func make(
        from context: ModelContext,
        appVersion: String = BackupSnapshotBuilder.currentAppVersion,
        exportedAt: Date = Date(),
        defaults: UserDefaults = .standard
    ) throws -> BackupSnapshot {
        let projects = try context.fetch(FetchDescriptor<Project>())
        let timeLogs = try context.fetch(FetchDescriptor<TimeLog>())
        let workNotes = try context.fetch(FetchDescriptor<WorkNote>())
        let sessions = try context.fetch(FetchDescriptor<ActiveSession>())

        return BackupSnapshot(
            appVersion: appVersion,
            exportedAt: exportedAt,
            projects: projectRecords(projects),
            timeLogs: timeLogRecords(timeLogs),
            workNotes: workNoteRecords(workNotes),
            activeSessions: activeSessionRecords(sessions),
            settings: settingsRecord(from: defaults)
        )
    }

    // MARK: - レコード変換
    //
    // 並びは投入順に依らず一意に決まるようソートする（同じデータからは同じ JSON が出る）。

    private static func projectRecords(_ projects: [Project]) -> [BackupSnapshot.ProjectRecord] {
        projects
            .map {
                BackupSnapshot.ProjectRecord(
                    id: $0.id, name: $0.name, colorHex: $0.colorHex,
                    createdAt: $0.createdAt, sortOrder: $0.sortOrder
                )
            }
            .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
    }

    private static func timeLogRecords(_ logs: [TimeLog]) -> [BackupSnapshot.TimeLogRecord] {
        logs
            .map {
                BackupSnapshot.TimeLogRecord(
                    id: $0.id, startDate: $0.startDate, endDate: $0.endDate,
                    projectID: $0.project?.id, notes: $0.notes
                )
            }
            .sorted { ($0.startDate, $0.id.uuidString) < ($1.startDate, $1.id.uuidString) }
    }

    private static func workNoteRecords(_ notes: [WorkNote]) -> [BackupSnapshot.WorkNoteRecord] {
        notes
            .map {
                BackupSnapshot.WorkNoteRecord(
                    id: $0.id, text: $0.text,
                    projectIDs: $0.projects.map(\.id).sorted { $0.uuidString < $1.uuidString }
                )
            }
            .sorted { ($0.text, $0.id.uuidString) < ($1.text, $1.id.uuidString) }
    }

    private static func activeSessionRecords(
        _ sessions: [ActiveSession]
    ) -> [BackupSnapshot.ActiveSessionRecord] {
        sessions
            .map {
                BackupSnapshot.ActiveSessionRecord(id: $0.id, startDate: $0.startDate, endDate: $0.endDate)
            }
            .sorted { ($0.startDate, $0.id.uuidString) < ($1.startDate, $1.id.uuidString) }
    }

    /// 設定は `AppSettings` 経由で読む（既定値の登録と値の正規化を一箇所に保つため）。
    private static func settingsRecord(from defaults: UserDefaults) -> BackupSnapshot.SettingsRecord {
        let settings = AppSettings(defaults: defaults)
        return BackupSnapshot.SettingsRecord(
            idleDetectionEnabled: settings.idleDetectionEnabled,
            idleThresholdMinutes: settings.idleThresholdMinutes,
            idleAlertEnabled: settings.idleAlertEnabled,
            allowConcurrentTracking: settings.allowConcurrentTracking,
            timelineSnapMinutes: settings.timelineSnapMinutes,
            promptForWorkNoteOnStop: settings.promptForWorkNoteOnStop,
            dimBlocksWithoutNotes: settings.dimBlocksWithoutNotes,
            displayLanguage: settings.displayLanguage.rawValue
        )
    }
}
