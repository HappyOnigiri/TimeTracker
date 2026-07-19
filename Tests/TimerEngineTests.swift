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
        let startDate = TestSupport.date(2025, 1, 10, 9, 0)
        let endDate = TestSupport.date(2025, 1, 10, 10, 0)

        engine.start(project, now: startDate)
        #expect(engine.isRunning(project))
        #expect(engine.isAnyRunning)

        engine.stop(project, now: endDate)
        #expect(!engine.isRunning(project))
        #expect(!engine.isAnyRunning)

        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs.count == 1)
        #expect(logs[0].startDate == startDate)
        #expect(logs[0].endDate == endDate)
    }

    @Test("stopAll は稼働中のすべてを停止する")
    func stopAllStopsEverything() throws {
        let defaults = UserDefaults.standard
        let savedConcurrent = defaults.object(forKey: AppSettingsKey.allowConcurrentTracking)
        defer { restoreDefault(savedConcurrent, forKey: AppSettingsKey.allowConcurrentTracking) }
        defaults.set(true, forKey: AppSettingsKey.allowConcurrentTracking)
        let context = try TestSupport.makeContext()
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

    @Test("同時測定オフでは通常開始時に現在時刻で他を停止する")
    func nonConcurrentStopsOthers() throws {
        let defaults = UserDefaults.standard
        let savedConcurrent = defaults.object(forKey: AppSettingsKey.allowConcurrentTracking)
        defer { restoreDefault(savedConcurrent, forKey: AppSettingsKey.allowConcurrentTracking) }
        defaults.set(false, forKey: AppSettingsKey.allowConcurrentTracking)
        let context = try TestSupport.makeContext()
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        context.insert(projectA)
        context.insert(projectB)
        let engine = TimerEngine()
        engine.configure(context: context)
        let startA = TestSupport.date(2025, 1, 10, 9, 0)
        let startB = TestSupport.date(2025, 1, 10, 10, 0)

        engine.start(projectA, now: startA)
        engine.start(projectB, now: startB)

        #expect(engine.isRunning(projectB))
        #expect(!engine.isRunning(projectA))
        #expect(engine.runningProjectIDs.count == 1)
        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        let logA = try #require(logs.first { $0.project?.id == projectA.id })
        let logB = try #require(logs.first { $0.project?.id == projectB.id })
        #expect(logA.startDate == startA)
        #expect(logA.endDate == startB)
        #expect(logB.startDate == startB)
        #expect(logB.endDate == nil)
    }

    @Test("アイドル検知は離席開始時刻（now - idle）でログを閉じる")
    func checkIdleStopsAtAbsenceStart() throws {
        let context = try TestSupport.makeContext()
        let defaults = UserDefaults.standard
        let savedEnabled = defaults.object(forKey: AppSettingsKey.idleDetectionEnabled)
        let savedThreshold = defaults.object(forKey: AppSettingsKey.idleThresholdMinutes)
        defer {
            restoreDefault(savedEnabled, forKey: AppSettingsKey.idleDetectionEnabled)
            restoreDefault(savedThreshold, forKey: AppSettingsKey.idleThresholdMinutes)
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
            restoreDefault(savedEnabled, forKey: AppSettingsKey.idleDetectionEnabled)
            restoreDefault(savedThreshold, forKey: AppSettingsKey.idleThresholdMinutes)
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
            restoreDefault(savedEnabled, forKey: AppSettingsKey.idleDetectionEnabled)
            restoreDefault(savedThreshold, forKey: AppSettingsKey.idleThresholdMinutes)
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

    private func restoreDefault(_ value: Any?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

extension TimerEngineTests {
    @Test("指定した過去日時から開始できる")
    func startsRetroactivelyAtSpecifiedDate() throws {
        let context = try TestSupport.makeContext()
        let project = Project(name: "A")
        context.insert(project)
        let engine = TimerEngine()
        engine.configure(context: context)
        let startDate = TestSupport.date(2025, 1, 10, 9, 30)
        let now = TestSupport.date(2025, 1, 10, 10, 0)

        let result = engine.startRetroactively(project, at: startDate, now: now)

        #expect(result == .started)
        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs.count == 1)
        #expect(logs[0].startDate == startDate)
        #expect(logs[0].endDate == nil)
        #expect(engine.isRunning(project))
        #expect(engine.isAnyRunning)
        #expect(engine.runningStartDate(for: project) == startDate)
    }

    @Test("現在時刻と同値なら遡及開始できる")
    func startsRetroactivelyAtCurrentDate() throws {
        let context = try TestSupport.makeContext()
        let project = Project(name: "A")
        context.insert(project)
        let engine = TimerEngine()
        engine.configure(context: context)
        let now = TestSupport.date(2025, 1, 10, 10, 0)

        let result = engine.startRetroactively(project, at: now, now: now)

        #expect(result == .started)
        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs.count == 1)
        #expect(logs[0].startDate == now)
    }

    @Test("未来日時の遡及開始を拒否する")
    func rejectsFutureRetroactiveStart() throws {
        let context = try TestSupport.makeContext()
        let project = Project(name: "A")
        context.insert(project)
        let engine = TimerEngine()
        engine.configure(context: context)
        let now = TestSupport.date(2025, 1, 10, 10, 0)
        let future = TestSupport.date(2025, 1, 10, 10, 1)

        let result = engine.startRetroactively(project, at: future, now: now)

        #expect(result == .futureStartDate)
        #expect(try context.fetch(FetchDescriptor<TimeLog>()).isEmpty)
        #expect(!engine.isAnyRunning)
    }

    @Test("遡及開始の過去方向に下限を設けない")
    func startsRetroactivelyWithoutPastLimit() throws {
        let context = try TestSupport.makeContext()
        let project = Project(name: "A")
        context.insert(project)
        let engine = TimerEngine()
        engine.configure(context: context)
        let oldDate = TestSupport.date(2000, 1, 1, 0, 0)
        let now = TestSupport.date(2025, 1, 10, 10, 0)

        let result = engine.startRetroactively(project, at: oldDate, now: now)

        #expect(result == .started)
        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs.count == 1)
        #expect(logs[0].startDate == oldDate)
    }

    @Test("同時測定オフで別プロジェクトが計測中なら遡及開始を拒否する")
    func rejectsRetroactiveStartWhenAnotherProjectIsRunning() throws {
        let defaults = UserDefaults.standard
        let savedConcurrent = defaults.object(forKey: AppSettingsKey.allowConcurrentTracking)
        defer { restoreDefault(savedConcurrent, forKey: AppSettingsKey.allowConcurrentTracking) }
        defaults.set(false, forKey: AppSettingsKey.allowConcurrentTracking)
        let context = try TestSupport.makeContext()
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        context.insert(projectA)
        context.insert(projectB)
        let engine = TimerEngine()
        engine.configure(context: context)
        let existingStart = TestSupport.date(2025, 1, 10, 9, 0)
        let retroactiveStart = TestSupport.date(2025, 1, 10, 9, 30)
        let now = TestSupport.date(2025, 1, 10, 10, 0)
        engine.start(projectA, now: existingStart)

        let result = engine.startRetroactively(projectB, at: retroactiveStart, now: now)

        #expect(result == .anotherProjectIsRunning)
        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs.count == 1)
        #expect(logs[0].project?.id == projectA.id)
        #expect(logs[0].startDate == existingStart)
        #expect(logs[0].endDate == nil)
        #expect(engine.runningProjectIDs == [projectA.id])
        #expect(engine.pendingNoteLogs.isEmpty)
    }

    @Test("同時測定オンなら別プロジェクトを維持して遡及開始できる")
    func startsRetroactivelyAlongsideAnotherProject() throws {
        let defaults = UserDefaults.standard
        let savedConcurrent = defaults.object(forKey: AppSettingsKey.allowConcurrentTracking)
        defer { restoreDefault(savedConcurrent, forKey: AppSettingsKey.allowConcurrentTracking) }
        defaults.set(true, forKey: AppSettingsKey.allowConcurrentTracking)
        let context = try TestSupport.makeContext()
        let projectA = Project(name: "A")
        let projectB = Project(name: "B")
        context.insert(projectA)
        context.insert(projectB)
        let engine = TimerEngine()
        engine.configure(context: context)
        let existingStart = TestSupport.date(2025, 1, 10, 9, 0)
        let retroactiveStart = TestSupport.date(2025, 1, 10, 9, 30)
        let now = TestSupport.date(2025, 1, 10, 10, 0)
        engine.start(projectA, now: existingStart)

        let result = engine.startRetroactively(projectB, at: retroactiveStart, now: now)

        #expect(result == .started)
        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs.count == 2)
        let logA = try #require(logs.first { $0.project?.id == projectA.id })
        let logB = try #require(logs.first { $0.project?.id == projectB.id })
        #expect(logA.startDate == existingStart)
        #expect(logA.endDate == nil)
        #expect(logB.startDate == retroactiveStart)
        #expect(logB.endDate == nil)
        #expect(engine.runningProjectIDs == [projectA.id, projectB.id])
    }

    @Test("計測中の対象プロジェクトには二重ログを作らない")
    func rejectsDuplicateRetroactiveStart() throws {
        let defaults = UserDefaults.standard
        let savedConcurrent = defaults.object(forKey: AppSettingsKey.allowConcurrentTracking)
        defer { restoreDefault(savedConcurrent, forKey: AppSettingsKey.allowConcurrentTracking) }
        defaults.set(false, forKey: AppSettingsKey.allowConcurrentTracking)
        let context = try TestSupport.makeContext()
        let project = Project(name: "A")
        context.insert(project)
        let engine = TimerEngine()
        engine.configure(context: context)
        let existingStart = TestSupport.date(2025, 1, 10, 9, 0)
        let now = TestSupport.date(2025, 1, 10, 10, 0)
        engine.start(project, now: existingStart)

        let result = engine.startRetroactively(
            project,
            at: TestSupport.date(2025, 1, 10, 9, 30),
            now: now
        )

        #expect(result == .alreadyRunning)
        let logs = try context.fetch(FetchDescriptor<TimeLog>())
        #expect(logs.count == 1)
        #expect(logs[0].startDate == existingStart)
        #expect(logs[0].endDate == nil)
    }

    @Test("未configureのエンジンは遡及開始を安全に拒否する")
    func rejectsRetroactiveStartWithoutContext() {
        let engine = TimerEngine()
        let project = Project(name: "A")
        let now = TestSupport.date(2025, 1, 10, 10, 0)

        let result = engine.startRetroactively(project, at: now, now: now)

        #expect(result == .engineNotConfigured)
        #expect(!engine.isAnyRunning)
    }

}
