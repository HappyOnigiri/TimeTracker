import Foundation
import SwiftData
import Testing
@testable import TimeTracker

// ModelContainer を共有するため直列実行（並列時の SwiftData 競合を回避）。
@MainActor
@Suite(.serialized)
struct BackupSnapshotBuilderTests {
    /// `UserDefaults.standard` を汚さないための専用スイート。
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "BackupSnapshotBuilderTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    @Test("4 モデルの全件と多対多の関連を書き出す")
    func capturesAllModels() throws {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let alpha = Project(name: "Alpha", colorHex: "#111111", sortOrder: 0)
        let beta = Project(name: "Beta", colorHex: "#222222", sortOrder: 1)
        context.insert(alpha)
        context.insert(beta)
        let log = TimeLog(
            project: alpha,
            startDate: TestSupport.date(2026, 9, 20, 9, 0),
            endDate: TestSupport.date(2026, 9, 20, 10, 0),
            notes: ["設計"]
        )
        context.insert(log)
        // プロジェクト未設定のログも正当な状態として書き出せること。
        context.insert(TimeLog(project: nil, startDate: TestSupport.date(2026, 9, 20, 11, 0)))
        context.insert(WorkNote(text: "設計", projects: [alpha, beta]))
        context.insert(ActiveSession(startDate: TestSupport.date(2026, 9, 20, 8, 0), endDate: nil))
        try context.save()

        let snapshot = try BackupSnapshotBuilder.make(
            from: context, appVersion: "9.9.9",
            exportedAt: TestSupport.date(2026, 9, 21), defaults: defaults
        )

        #expect(snapshot.formatVersion == BackupSnapshot.currentFormatVersion)
        #expect(snapshot.appVersion == "9.9.9")
        #expect(snapshot.projects.map(\.name) == ["Alpha", "Beta"])
        #expect(snapshot.timeLogs.count == 2)
        #expect(snapshot.timeLogs[0].projectID == alpha.id)
        #expect(snapshot.timeLogs[0].notes == ["設計"])
        #expect(snapshot.timeLogs[1].projectID == nil)
        #expect(snapshot.timeLogs[1].endDate == nil)
        #expect(snapshot.workNotes.count == 1)
        #expect(snapshot.workNotes[0].projectIDs.count == 2)
        #expect(snapshot.workNotes[0].projectIDs.contains(alpha.id))
        #expect(snapshot.workNotes[0].projectIDs.contains(beta.id))
        #expect(snapshot.activeSessions.count == 1)
        #expect(snapshot.activeSessions[0].endDate == nil)
    }

    @Test("投入順を変えても同じ JSON になる")
    func ordersRecordsDeterministically() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // 同じ内容を逆順に投入した 2 つの Context から、同じバイト列が出ること。
        let first = try makeFixtureData(reversed: false, defaults: defaults)
        let second = try makeFixtureData(reversed: true, defaults: defaults)
        #expect(first == second)
    }

    /// 同一内容のデータを投入順だけ変えて作り、バックアップの JSON を返す。
    private func makeFixtureData(reversed: Bool, defaults: UserDefaults) throws -> Data {
        let context = try TestSupport.makeContext()
        defer { TestSupport.clearWorkNoteRelationships(in: context) }

        let projects = Self.makeProjects()
        for project in reversed ? projects.reversed() : projects {
            context.insert(project)
        }
        try context.save()

        for log in Self.ordered(Self.makeLogs(for: projects), reversed: reversed) {
            context.insert(log)
        }
        for note in Self.ordered(Self.makeNotes(for: projects), reversed: reversed) {
            context.insert(note)
        }
        for session in Self.ordered(Self.makeSessions(), reversed: reversed) {
            context.insert(session)
        }
        try context.save()

        let snapshot = try BackupSnapshotBuilder.make(
            from: context, appVersion: "1.0.0",
            exportedAt: TestSupport.date(2026, 9, 21), defaults: defaults
        )
        return try BackupCodec.encode(snapshot)
    }

    private static func ordered<T>(_ values: [T], reversed: Bool) -> [T] {
        reversed ? values.reversed() : values
    }

    private static func makeProjects() -> [Project] {
        let ids = [
            UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
            UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
        ]
        return ids.enumerated().map { index, id in
            let project = Project(name: "P\(index)", sortOrder: index)
            project.id = id
            project.createdAt = TestSupport.date(2026, 9, 1)
            return project
        }
    }

    private static func makeLogs(for projects: [Project]) -> [TimeLog] {
        let logs = [
            TimeLog(
                project: projects[0], startDate: TestSupport.date(2026, 9, 20, 9, 0),
                endDate: TestSupport.date(2026, 9, 20, 10, 0)
            ),
            TimeLog(
                project: projects[1], startDate: TestSupport.date(2026, 9, 20, 11, 0),
                endDate: TestSupport.date(2026, 9, 20, 12, 0)
            )
        ]
        logs[0].id = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
        logs[1].id = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
        return logs
    }

    private static func makeNotes(for projects: [Project]) -> [WorkNote] {
        let notes = [
            WorkNote(text: "設計", projects: projects),
            WorkNote(text: "実装", projects: [projects[0]])
        ]
        notes[0].id = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
        notes[1].id = UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!
        return notes
    }

    private static func makeSessions() -> [ActiveSession] {
        let sessions = [
            ActiveSession(startDate: TestSupport.date(2026, 9, 20, 8, 0), endDate: nil),
            ActiveSession(
                startDate: TestSupport.date(2026, 9, 19, 8, 0),
                endDate: TestSupport.date(2026, 9, 19, 9, 0)
            )
        ]
        sessions[0].id = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!
        sessions[1].id = UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!
        return sessions
    }

    @Test("設定 8 キーを書き出す")
    func capturesSettings() throws {
        let context = try TestSupport.makeContext()
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: AppSettingsKey.idleDetectionEnabled)
        defaults.set(17, forKey: AppSettingsKey.idleThresholdMinutes)
        defaults.set(false, forKey: AppSettingsKey.idleAlertEnabled)
        defaults.set(false, forKey: AppSettingsKey.allowConcurrentTracking)
        defaults.set(30, forKey: AppSettingsKey.timelineSnapMinutes)
        defaults.set(false, forKey: AppSettingsKey.promptForWorkNoteOnStop)
        defaults.set(false, forKey: AppSettingsKey.dimBlocksWithoutNotes)
        defaults.set(AppLanguage.simplifiedChinese.rawValue, forKey: AppSettingsKey.displayLanguage)

        let settings = try BackupSnapshotBuilder.make(
            from: context, appVersion: "1.0.0",
            exportedAt: TestSupport.date(2026, 9, 21), defaults: defaults
        ).settings

        #expect(settings.idleDetectionEnabled == false)
        #expect(settings.idleThresholdMinutes == 17)
        #expect(settings.idleAlertEnabled == false)
        #expect(settings.allowConcurrentTracking == false)
        #expect(settings.timelineSnapMinutes == 30)
        #expect(settings.promptForWorkNoteOnStop == false)
        #expect(settings.dimBlocksWithoutNotes == false)
        #expect(settings.displayLanguage == AppLanguage.simplifiedChinese.rawValue)
    }
}
