import Foundation
import SwiftData
import Testing
@testable import TimeTracker

// 異常終了・再起動をまたぐ計測ログの後始末に関するテスト。
// 共有 Defaults を書き換えるため直列実行。
@MainActor
@Suite(.serialized)
struct TimerEngineOrphanTests {
    @Test("heartbeat がなければ起動時に開きっぱなしのログを開始時刻で閉じる")
    func closesOrphanedLogsOnConfigure() throws {
        let defaults = UserDefaults.standard
        let savedHeartbeat = defaults.object(forKey: AppSettingsKey.lastHeartbeat)
        defer { restoreDefault(savedHeartbeat, forKey: AppSettingsKey.lastHeartbeat) }
        defaults.removeObject(forKey: AppSettingsKey.lastHeartbeat)

        let context = try TestSupport.makeContext()
        let project = Project(name: "A")
        context.insert(project)
        let orphan = TimeLog(project: project, startDate: TestSupport.date(2025, 1, 10, 9, 0), endDate: nil)
        context.insert(orphan)
        try context.save()

        let engine = TimerEngine()
        engine.configure(context: context)
        #expect(!engine.isAnyRunning)
        #expect(orphan.endDate == orphan.startDate)
    }

    @Test("起動時に開きっぱなしのログを最後の heartbeat で閉じる")
    func closesOrphanedLogsAtHeartbeat() throws {
        let defaults = UserDefaults.standard
        let savedHeartbeat = defaults.object(forKey: AppSettingsKey.lastHeartbeat)
        defer { restoreDefault(savedHeartbeat, forKey: AppSettingsKey.lastHeartbeat) }
        let startDate = TestSupport.date(2025, 1, 10, 9, 0)
        let heartbeat = TestSupport.date(2025, 1, 10, 10, 0)
        AppSettings().recordHeartbeat(heartbeat)

        let context = try TestSupport.makeContext()
        let project = Project(name: "A")
        context.insert(project)
        let orphan = TimeLog(project: project, startDate: startDate, endDate: nil)
        context.insert(orphan)
        try context.save()

        let engine = TimerEngine()
        engine.configure(context: context)
        #expect(!engine.isAnyRunning)
        #expect(orphan.endDate == heartbeat)
    }

    @Test("開始より古い heartbeat では開始時刻より前に巻き戻さない")
    func staleHeartbeatDoesNotPrecedeStart() throws {
        let defaults = UserDefaults.standard
        let savedHeartbeat = defaults.object(forKey: AppSettingsKey.lastHeartbeat)
        defer { restoreDefault(savedHeartbeat, forKey: AppSettingsKey.lastHeartbeat) }
        let startDate = TestSupport.date(2025, 1, 10, 9, 0)
        AppSettings().recordHeartbeat(TestSupport.date(2025, 1, 10, 8, 0))

        let context = try TestSupport.makeContext()
        let project = Project(name: "A")
        context.insert(project)
        let orphan = TimeLog(project: project, startDate: startDate, endDate: nil)
        context.insert(orphan)
        try context.save()

        let engine = TimerEngine()
        engine.configure(context: context)
        #expect(orphan.endDate == startDate)
    }

    private func restoreDefault(_ value: Any?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
