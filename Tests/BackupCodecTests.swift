import Foundation
import Testing
@testable import TimeTracker

struct BackupCodecTests {
    /// 秒精度の日付だけを使う（バックアップの日付は ISO 8601 の秒精度で保存される）。
    private static func makeSnapshot() -> BackupSnapshot {
        let projectID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        return BackupSnapshot(
            appVersion: "1.2.3",
            exportedAt: TestSupport.date(2026, 9, 21, 10, 0),
            projects: [
                BackupSnapshot.ProjectRecord(
                    id: projectID, name: "開発", colorHex: "#4E9BFF",
                    createdAt: TestSupport.date(2026, 9, 1), sortOrder: 0
                )
            ],
            timeLogs: [
                BackupSnapshot.TimeLogRecord(
                    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!,
                    startDate: TestSupport.date(2026, 9, 20, 9, 0),
                    endDate: TestSupport.date(2026, 9, 20, 10, 30),
                    projectID: projectID, notes: ["設計", "実装"]
                )
            ],
            workNotes: [
                BackupSnapshot.WorkNoteRecord(
                    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!,
                    text: "設計", projectIDs: [projectID]
                )
            ],
            activeSessions: [
                BackupSnapshot.ActiveSessionRecord(
                    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!,
                    startDate: TestSupport.date(2026, 9, 20, 8, 50), endDate: nil
                )
            ],
            settings: BackupSnapshot.SettingsRecord(
                idleDetectionEnabled: false, idleThresholdMinutes: 15, displayLanguage: "ja"
            )
        )
    }

    @Test("スナップショットは JSON を往復しても同値になる")
    func roundTripsSnapshot() throws {
        let snapshot = Self.makeSnapshot()
        let decoded = try BackupCodec.decode(BackupCodec.encode(snapshot))
        #expect(decoded == snapshot)
    }

    @Test("同じスナップショットからは同じバイト列が出る")
    func encodesDeterministically() throws {
        let snapshot = Self.makeSnapshot()
        #expect(try BackupCodec.encode(snapshot) == BackupCodec.encode(snapshot))
    }

    @Test("現行より新しいフォーマット版数は専用エラーで弾く")
    func rejectsNewerFormatVersion() throws {
        var snapshot = Self.makeSnapshot()
        snapshot.formatVersion = BackupSnapshot.currentFormatVersion + 1
        let data = try BackupCodec.encode(snapshot)
        #expect(throws: BackupError.unsupportedFormatVersion(snapshot.formatVersion)) {
            try BackupCodec.decode(data)
        }
    }

    @Test("壊れた JSON は読み取り失敗として扱う")
    func rejectsMalformedData() {
        #expect(throws: BackupError.malformedFile) {
            try BackupCodec.decode(Data("{ not json".utf8))
        }
        // 版数は読めても中身が欠けている場合も読み取り失敗にする。
        #expect(throws: BackupError.malformedFile) {
            try BackupCodec.decode(Data(#"{"formatVersion":1}"#.utf8))
        }
    }
}
