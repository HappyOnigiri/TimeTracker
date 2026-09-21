import Foundation

/// アプリの全データ（SwiftData の 4 モデルとアプリ設定）を 1 つにまとめた DTO。
///
/// SwiftData / AppKit のどちらにも依存しない。保存先（ファイル・将来の git リポジトリ）は
/// `BackupService` だけが知り、この型と `BackupCodec` は保存先を意識しない。
struct BackupSnapshot: Codable, Equatable {
    /// 現行のフォーマット版数。読み込み互換の判断に使う。
    ///
    /// SwiftData 側に `VersionedSchema` が無くスキーマ版数の概念が存在しないため、
    /// バックアップファイル自身が版数を持つ。
    static let currentFormatVersion = 1

    var formatVersion: Int
    /// 書き出したアプリのバージョン（CFBundleShortVersionString）。復元時は参照しない。
    var appVersion: String
    var exportedAt: Date
    var projects: [ProjectRecord]
    var timeLogs: [TimeLogRecord]
    var workNotes: [WorkNoteRecord]
    var activeSessions: [ActiveSessionRecord]
    var settings: SettingsRecord

    init(
        formatVersion: Int = BackupSnapshot.currentFormatVersion,
        appVersion: String,
        exportedAt: Date,
        projects: [ProjectRecord] = [],
        timeLogs: [TimeLogRecord] = [],
        workNotes: [WorkNoteRecord] = [],
        activeSessions: [ActiveSessionRecord] = [],
        settings: SettingsRecord = SettingsRecord()
    ) {
        self.formatVersion = formatVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.projects = projects
        self.timeLogs = timeLogs
        self.workNotes = workNotes
        self.activeSessions = activeSessions
        self.settings = settings
    }
}

extension BackupSnapshot {
    struct ProjectRecord: Codable, Equatable {
        var id: UUID
        var name: String
        var colorHex: String
        var createdAt: Date
        var sortOrder: Int
    }

    /// 参照はオブジェクトではなく UUID で持つ。`projectID` が nil のログも正当な状態。
    struct TimeLogRecord: Codable, Equatable {
        var id: UUID
        var startDate: Date
        /// 終了時刻。`nil` は計測中を表す（復元時も nil のまま投入する）。
        var endDate: Date?
        var projectID: UUID?
        var notes: [String]
    }

    struct WorkNoteRecord: Codable, Equatable {
        var id: UUID
        var text: String
        /// 多対多で紐づくプロジェクトの ID。
        var projectIDs: [UUID]
    }

    struct ActiveSessionRecord: Codable, Equatable {
        var id: UUID
        var startDate: Date
        var endDate: Date?
    }

    /// UserDefaults に保存する設定。すべて Optional で、キーの欠落＝現状維持を表す。
    ///
    /// `lastHeartbeat` はクラッシュ復旧用のランタイム状態なので含めない。
    struct SettingsRecord: Codable, Equatable {
        var idleDetectionEnabled: Bool?
        var idleThresholdMinutes: Int?
        var idleAlertEnabled: Bool?
        var allowConcurrentTracking: Bool?
        var timelineSnapMinutes: Int?
        var promptForWorkNoteOnStop: Bool?
        var dimBlocksWithoutNotes: Bool?
        /// `AppLanguage` の rawValue。未知の値は復元時に既定値へ戻す。
        var displayLanguage: String?

        init(
            idleDetectionEnabled: Bool? = nil,
            idleThresholdMinutes: Int? = nil,
            idleAlertEnabled: Bool? = nil,
            allowConcurrentTracking: Bool? = nil,
            timelineSnapMinutes: Int? = nil,
            promptForWorkNoteOnStop: Bool? = nil,
            dimBlocksWithoutNotes: Bool? = nil,
            displayLanguage: String? = nil
        ) {
            self.idleDetectionEnabled = idleDetectionEnabled
            self.idleThresholdMinutes = idleThresholdMinutes
            self.idleAlertEnabled = idleAlertEnabled
            self.allowConcurrentTracking = allowConcurrentTracking
            self.timelineSnapMinutes = timelineSnapMinutes
            self.promptForWorkNoteOnStop = promptForWorkNoteOnStop
            self.dimBlocksWithoutNotes = dimBlocksWithoutNotes
            self.displayLanguage = displayLanguage
        }
    }
}
