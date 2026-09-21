import Foundation
import SwiftData
import Testing
@testable import TimeTracker

// ModelContainer を共有するため直列実行（並列時の SwiftData 競合を回避）。
@MainActor
@Suite(.serialized)
struct BackupRestoreTests {
    private static let projectID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private static let logID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
    private static let runningLogID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
    private static let noteID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
    private static let sessionID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!

    /// `UserDefaults.standard` を汚さないための専用スイート。
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "BackupRestoreTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    private static func makeSnapshot(
        timeLogs: [BackupSnapshot.TimeLogRecord]? = nil,
        workNotes: [BackupSnapshot.WorkNoteRecord]? = nil,
        settings: BackupSnapshot.SettingsRecord = BackupSnapshot.SettingsRecord()
    ) -> BackupSnapshot {
        BackupSnapshot(
            appVersion: "1.0.0",
            exportedAt: TestSupport.date(2026, 9, 21),
            projects: [
                BackupSnapshot.ProjectRecord(
                    id: projectID, name: "Alpha", colorHex: "#123456",
                    createdAt: TestSupport.date(2026, 9, 1), sortOrder: 3
                )
            ],
            timeLogs: timeLogs ?? [
                BackupSnapshot.TimeLogRecord(
                    id: logID, startDate: TestSupport.date(2026, 9, 20, 9, 0),
                    endDate: TestSupport.date(2026, 9, 20, 10, 0),
                    projectID: projectID, notes: ["設計"]
                ),
                BackupSnapshot.TimeLogRecord(
                    id: runningLogID, startDate: TestSupport.date(2026, 9, 20, 11, 0),
                    endDate: nil, projectID: projectID, notes: []
                )
            ],
            workNotes: workNotes ?? [
                BackupSnapshot.WorkNoteRecord(id: noteID, text: "設計", projectIDs: [projectID])
            ],
            activeSessions: [
                BackupSnapshot.ActiveSessionRecord(
                    id: sessionID, startDate: TestSupport.date(2026, 9, 20, 8, 0), endDate: nil
                )
            ],
            settings: settings
        )
    }

    /// 復元先に残っていてはいけない既存データを投入する。
    private func insertExistingData(into context: ModelContext) throws {
        let project = Project(name: "既存", colorHex: "#FFFFFF", sortOrder: 0)
        context.insert(project)
        context.insert(TimeLog(project: project, startDate: TestSupport.date(2026, 1, 1, 9, 0)))
        context.insert(WorkNote(text: "既存の作業", projects: [project]))
        context.insert(ActiveSession(startDate: TestSupport.date(2026, 1, 1, 8, 0)))
        try context.save()
    }

    @Test("既存データを全置換し、バックアップの内容と一致する")
    func replacesAllExistingData() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try insertExistingData(into: context)

        try BackupRestorer.restore(Self.makeSnapshot(), into: context, defaults: defaults)

        let projects = try context.fetch(FetchDescriptor<Project>())
        #expect(projects.count == 1)
        #expect(projects[0].id == Self.projectID)
        #expect(projects[0].name == "Alpha")
        #expect(projects[0].colorHex == "#123456")
        #expect(projects[0].createdAt == TestSupport.date(2026, 9, 1))
        #expect(projects[0].sortOrder == 3)

        let logs = try context.fetch(FetchDescriptor<TimeLog>()).sorted { $0.startDate < $1.startDate }
        #expect(logs.count == 2)
        #expect(logs[0].id == Self.logID)
        #expect(logs[0].project?.id == Self.projectID)
        #expect(logs[0].notes == ["設計"])

        let notes = try context.fetch(FetchDescriptor<WorkNote>())
        #expect(notes.count == 1)
        #expect(notes[0].id == Self.noteID)
        #expect(notes[0].text == "設計")
        #expect(notes[0].projects.map(\.id) == [Self.projectID])

        let sessions = try context.fetch(FetchDescriptor<ActiveSession>())
        #expect(sessions.count == 1)
        #expect(sessions[0].id == Self.sessionID)
    }

    @Test("計測中のログとセッションは endDate が nil のまま復元される")
    func keepsOpenRecordsOpen() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        try BackupRestorer.restore(Self.makeSnapshot(), into: context, defaults: defaults)

        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs.filter { $0.endDate == nil }.map(\.id) == [Self.runningLogID])
        let sessions = try context.fetch(FetchDescriptor<ActiveSession>())
        #expect(sessions.allSatisfy { $0.endDate == nil })
    }

    @Test("未知のプロジェクト参照は落として復元を続ける")
    func dropsUnknownProjectReferences() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let missingID = UUID(uuidString: "00000000-0000-0000-0000-00000000FFFF")!
        let snapshot = Self.makeSnapshot(
            timeLogs: [
                BackupSnapshot.TimeLogRecord(
                    id: Self.logID, startDate: TestSupport.date(2026, 9, 20, 9, 0),
                    endDate: TestSupport.date(2026, 9, 20, 10, 0),
                    projectID: missingID, notes: []
                )
            ],
            workNotes: [
                BackupSnapshot.WorkNoteRecord(
                    id: Self.noteID, text: "設計", projectIDs: [Self.projectID, missingID]
                )
            ]
        )

        try BackupRestorer.restore(snapshot, into: context, defaults: defaults)

        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs.count == 1)
        #expect(logs[0].project == nil)
        let notes = try context.fetch(FetchDescriptor<WorkNote>())
        #expect(notes.count == 1)
        #expect(notes[0].projects.map(\.id) == [Self.projectID])
    }

    @Test("設定 8 キーを復元する")
    func restoresSettings() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let snapshot = Self.makeSnapshot(settings: BackupSnapshot.SettingsRecord(
            idleDetectionEnabled: false, idleThresholdMinutes: 17, idleAlertEnabled: false,
            allowConcurrentTracking: false, timelineSnapMinutes: 15,
            promptForWorkNoteOnStop: false, dimBlocksWithoutNotes: false,
            displayLanguage: AppLanguage.simplifiedChinese.rawValue
        ))

        try BackupRestorer.restore(snapshot, into: context, defaults: defaults)

        let settings = AppSettings(defaults: defaults)
        #expect(settings.idleDetectionEnabled == false)
        #expect(settings.idleThresholdMinutes == 17)
        #expect(settings.idleAlertEnabled == false)
        #expect(settings.allowConcurrentTracking == false)
        #expect(settings.timelineSnapMinutes == 15)
        #expect(settings.promptForWorkNoteOnStop == false)
        #expect(settings.dimBlocksWithoutNotes == false)
        #expect(settings.displayLanguage == .simplifiedChinese)
    }

    @Test("不正な設定値は既定値へフォールバックする")
    func fallsBackOnInvalidSettings() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let snapshot = Self.makeSnapshot(settings: BackupSnapshot.SettingsRecord(
            timelineSnapMinutes: 7, displayLanguage: "unsupported"
        ))

        try BackupRestorer.restore(snapshot, into: context, defaults: defaults)

        #expect(
            defaults.integer(forKey: AppSettingsKey.timelineSnapMinutes)
                == AppSettingsDefault.timelineSnapMinutes
        )
        #expect(
            defaults.string(forKey: AppSettingsKey.displayLanguage)
                == AppSettingsDefault.displayLanguage.rawValue
        )
    }

    @Test("バックアップを書き出して復元すると同じ内容に戻る")
    func roundTripsThroughBackupData() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let source = try TestSupport.makeContext()
        let project = Project(name: "Alpha", colorHex: "#123456", sortOrder: 2)
        source.insert(project)
        try source.save()
        source.insert(TimeLog(
            project: project, startDate: TestSupport.date(2026, 9, 20, 9, 0),
            endDate: TestSupport.date(2026, 9, 20, 10, 0), notes: ["設計", "実装"]
        ))
        source.insert(WorkNote(text: "設計", projects: [project]))
        source.insert(ActiveSession(
            startDate: TestSupport.date(2026, 9, 20, 8, 0),
            endDate: TestSupport.date(2026, 9, 20, 8, 30)
        ))
        try source.save()
        let data = try BackupCodec.encode(
            BackupSnapshotBuilder.make(
                from: source, appVersion: "1.0.0",
                exportedAt: TestSupport.date(2026, 9, 21), defaults: defaults
            )
        )
        TestSupport.clearWorkNoteRelationships(in: source)

        // 別データが入った状態の Context へ復元し、バックアップと同じ JSON が得られること。
        let target = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: target) }
        try insertExistingData(into: target)
        try BackupRestorer.restore(BackupCodec.decode(data), into: target, defaults: defaults)

        let restored = try BackupCodec.encode(
            BackupSnapshotBuilder.make(
                from: target, appVersion: "1.0.0",
                exportedAt: TestSupport.date(2026, 9, 21), defaults: defaults
            )
        )
        #expect(restored == data)
    }
}
