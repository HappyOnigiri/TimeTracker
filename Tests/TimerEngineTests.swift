import Foundation
import SwiftData
import Testing
@testable import TimeTracker

// ModelContainer を生成するため直列実行（並列時の SwiftData 競合と共有 Defaults 競合を回避）。
@MainActor
@Suite(.serialized)
struct TimerEngineTests {
    @Test("開始でログが開き、停止で閉じる")
    func startThenStop() throws {
        let context = try TestSupport.makeContext()
        let project = Project(name: "A")
        context.insert(project)
        let engine = TimerEngine()
        engine.configure(context: context)

        engine.start(project, now: TestSupport.date(2025, 1, 10, 9, 0))
        #expect(engine.isRunning(project))
        #expect(engine.isAnyRunning)

        engine.stop(project, now: TestSupport.date(2025, 1, 10, 10, 0))
        #expect(!engine.isRunning(project))
        #expect(!engine.isAnyRunning)

        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs.count == 1)
        #expect(logs[0].endDate == TestSupport.date(2025, 1, 10, 10, 0))
    }

    @Test("stopAll は稼働中のすべてを停止する")
    func stopAllStopsEverything() throws {
        let context = try TestSupport.makeContext()
        UserDefaults.standard.set(true, forKey: AppSettingsKey.allowConcurrentTracking)
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        context.insert(projectA)
        context.insert(projectB)
        let engine = TimerEngine()
        engine.configure(context: context)

        engine.start(projectA)
        engine.start(projectB)
        #expect(engine.runningProjectIDs.count == 2)

        engine.stopAll()
        #expect(!engine.isAnyRunning)
    }

    @Test("同時測定オフでは開始時に他を停止する")
    func nonConcurrentStopsOthers() throws {
        let context = try TestSupport.makeContext()
        UserDefaults.standard.set(false, forKey: AppSettingsKey.allowConcurrentTracking)
        defer { UserDefaults.standard.set(true, forKey: AppSettingsKey.allowConcurrentTracking) }
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        context.insert(projectA)
        context.insert(projectB)
        let engine = TimerEngine()
        engine.configure(context: context)

        engine.start(projectA)
        engine.start(projectB)
        #expect(engine.isRunning(projectB))
        #expect(!engine.isRunning(projectA))
        #expect(engine.runningProjectIDs.count == 1)
    }

    @Test("アイドル検知は離席開始時刻（now - idle）でログを閉じる")
    func checkIdleStopsAtAbsenceStart() throws {
        let context = try TestSupport.makeContext()
        let defaults = UserDefaults.standard
        let savedEnabled = defaults.object(forKey: AppSettingsKey.idleDetectionEnabled)
        let savedThreshold = defaults.object(forKey: AppSettingsKey.idleThresholdMinutes)
        defer {
            defaults.set(savedEnabled, forKey: AppSettingsKey.idleDetectionEnabled)
            defaults.set(savedThreshold, forKey: AppSettingsKey.idleThresholdMinutes)
        }
        defaults.set(true, forKey: AppSettingsKey.idleDetectionEnabled)
        defaults.set(5, forKey: AppSettingsKey.idleThresholdMinutes)
        let project = Project(name: "A")
        context.insert(project)
        let engine = TimerEngine()
        engine.configure(context: context)

        engine.start(project, now: TestSupport.date(2025, 1, 10, 9, 0))
        // 10:00 時点で 10 分（600 秒, 既定閾値 5 分超）アイドル → 離席開始の 9:50 で停止。
        engine.checkIdle(now: TestSupport.date(2025, 1, 10, 10, 0), idleSeconds: 600)

        #expect(!engine.isAnyRunning)
        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs[0].endDate == TestSupport.date(2025, 1, 10, 9, 50))
    }

    @Test("離席開始がログ開始より前なら開始時刻でクランプする")
    func checkIdleClampsToLogStart() throws {
        let context = try TestSupport.makeContext()
        let defaults = UserDefaults.standard
        let savedEnabled = defaults.object(forKey: AppSettingsKey.idleDetectionEnabled)
        let savedThreshold = defaults.object(forKey: AppSettingsKey.idleThresholdMinutes)
        defer {
            defaults.set(savedEnabled, forKey: AppSettingsKey.idleDetectionEnabled)
            defaults.set(savedThreshold, forKey: AppSettingsKey.idleThresholdMinutes)
        }
        defaults.set(true, forKey: AppSettingsKey.idleDetectionEnabled)
        defaults.set(5, forKey: AppSettingsKey.idleThresholdMinutes)
        let project = Project(name: "A")
        context.insert(project)
        let engine = TimerEngine()
        engine.configure(context: context)

        engine.start(project, now: TestSupport.date(2025, 1, 10, 9, 55))
        // idle 30 分 → 離席開始は 9:30 だが、ログ開始(9:55)より前のため 9:55 にクランプ。
        engine.checkIdle(now: TestSupport.date(2025, 1, 10, 10, 0), idleSeconds: 1800)

        #expect(!engine.isAnyRunning)
        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs[0].endDate == TestSupport.date(2025, 1, 10, 9, 55))
    }

    @Test("アイドルが閾値未満なら停止しない")
    func checkIdleBelowThresholdKeepsRunning() throws {
        let context = try TestSupport.makeContext()
        let defaults = UserDefaults.standard
        let savedEnabled = defaults.object(forKey: AppSettingsKey.idleDetectionEnabled)
        let savedThreshold = defaults.object(forKey: AppSettingsKey.idleThresholdMinutes)
        defer {
            defaults.set(savedEnabled, forKey: AppSettingsKey.idleDetectionEnabled)
            defaults.set(savedThreshold, forKey: AppSettingsKey.idleThresholdMinutes)
        }
        defaults.set(true, forKey: AppSettingsKey.idleDetectionEnabled)
        defaults.set(5, forKey: AppSettingsKey.idleThresholdMinutes)
        let project = Project(name: "A")
        context.insert(project)
        let engine = TimerEngine()
        engine.configure(context: context)

        engine.start(project, now: TestSupport.date(2025, 1, 10, 9, 0))
        // 60 秒のみアイドル（既定閾値 5 分未満）→ 継続。
        engine.checkIdle(now: TestSupport.date(2025, 1, 10, 9, 1), idleSeconds: 60)

        #expect(engine.isRunning(project))
    }

    @Test("起動時に開きっぱなしのログを開始時刻で閉じる")
    func closesOrphanedLogsOnConfigure() throws {
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
}
