import AppKit
import Foundation
import Observation
import SwiftData
import SwiftUI

/// プロジェクトごとのタイマー開始/停止と、アイドル検知による自動停止を司る中核。
///
/// 計測中の状態は SwiftData の「終了していない TimeLog」で表現する。
/// `runningProjectIDs` は UI 更新用の派生キャッシュ。
@MainActor
@Observable
final class TimerEngine {
    private(set) var runningProjectIDs: Set<UUID> = []

    /// 測定中プロジェクトの色（sortOrder 順）。メニューバーアイコンの描画に使う。
    private(set) var runningColorHexes: [String] = []

    /// 測定中プロジェクトの計測開始時刻（プロジェクト ID → 最古の開始時刻）。
    /// 経過時間の表示に使う。
    private(set) var runningStartDates: [UUID: Date] = [:]

    /// アイドル自動停止で停止されたプロジェクト情報。通知表示に使う。
    private(set) var idleStoppedProjectNames: [String] = []
    @ObservationIgnored private var idleStoppedProjectIDs: Set<UUID> = []
    @ObservationIgnored private var idleAlertPanel: NSPanel?

    private(set) var pendingNoteLogs: [TimeLog] = []
    @ObservationIgnored private var workNotePanel: NSPanel?

    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var settings = AppSettings()
    @ObservationIgnored private var idleTimer: Timer?

    /// アイドル判定の監視間隔（秒）。
    private let idlePollInterval: TimeInterval = 5

    var isAnyRunning: Bool { !runningProjectIDs.isEmpty }

    /// View 層から ModelContext を受け取って初期化する。
    /// 前回セッションでクラッシュ等により開きっぱなしのログがあれば破棄する。
    func configure(context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        closeOrphanedLogs()
        refreshRunningState()
        startIdleMonitoring()
    }

    func isRunning(_ project: Project) -> Bool {
        runningProjectIDs.contains(project.id)
    }

    /// 計測中プロジェクトの計測開始時刻。計測していなければ nil。
    func runningStartDate(for project: Project) -> Date? {
        runningStartDates[project.id]
    }

    /// プロジェクトの計測を開始する。同時測定が無効なら他を停止してから開始する。
    func start(_ project: Project, now: Date = Date()) {
        guard let context else { return }
        guard !isRunning(project) else { return }
        if !settings.allowConcurrentTracking {
            stopAll(now: now, promptForNotes: true)
        }
        context.insert(TimeLog(project: project, startDate: now))
        save()
        refreshRunningState()
    }

    /// プロジェクトの計測を停止する。
    func stop(_ project: Project, now: Date = Date(), promptForNotes: Bool = false) {
        guard context != nil else { return }
        let targetID = project.id
        let openLogs = fetchOpenLogs().filter { $0.project?.id == targetID }
        for log in openLogs {
            log.endDate = now
        }
        if !openLogs.isEmpty { save() }
        refreshRunningState()
        if promptForNotes && settings.promptForWorkNoteOnStop && !openLogs.isEmpty {
            pendingNoteLogs.append(contentsOf: openLogs)
            showWorkNotePrompt()
        }
    }

    func toggle(_ project: Project, now: Date = Date()) {
        if isRunning(project) {
            stop(project, now: now, promptForNotes: true)
        } else {
            start(project, now: now)
        }
    }

    /// 稼働中のすべてのタイマーを停止する。
    func stopAll(now: Date = Date(), promptForNotes: Bool = false) {
        let openLogs = fetchOpenLogs()
        guard !openLogs.isEmpty else { return }
        for log in openLogs {
            log.endDate = now
        }
        save()
        refreshRunningState()
        if promptForNotes && settings.promptForWorkNoteOnStop {
            pendingNoteLogs.append(contentsOf: openLogs)
            showWorkNotePrompt()
        }
    }

    // MARK: - アイドル検知

    private func startIdleMonitoring() {
        idleTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: idlePollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.idleTimerFired()
            }
        }
        idleTimer = timer
    }

    private func idleTimerFired() {
        refrontIdleAlertIfNeeded()
        checkIdle()
    }

    private func refrontIdleAlertIfNeeded() {
        guard let panel = idleAlertPanel else { return }
        let idleSeconds = IdleDetector.secondsSinceLastInput()
        guard idleSeconds < settings.idleThresholdSeconds else { return }
        centerPanelOnCursorScreen(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// アイドル時間が閾値を超え、かつ計測中なら全停止する。
    /// 停止時刻は「離席が始まった時刻（now - idle）」に補正し、離席分を計測に含めない。
    /// `idleSeconds` は既定で実機のアイドル秒数を読むが、テストでは注入して決定性を得る。
    func checkIdle(now: Date = Date(), idleSeconds: TimeInterval = IdleDetector.secondsSinceLastInput()) {
        guard settings.idleDetectionEnabled else { return }
        guard isAnyRunning else { return }
        guard idleSeconds >= settings.idleThresholdSeconds else { return }
        let stopAt = now.addingTimeInterval(-idleSeconds)
        stopAllNotBefore(stopAt: stopAt, now: now)
    }

    /// 各ログの開始時刻より前にならないように補正しつつ全停止する。
    private func stopAllNotBefore(stopAt: Date, now: Date) {
        let openLogs = fetchOpenLogs()
        guard !openLogs.isEmpty else { return }

        let stoppedIDs = Set(openLogs.compactMap { $0.project?.id })

        for log in openLogs {
            log.endDate = max(stopAt, log.startDate)
        }
        save()
        refreshRunningState()

        if settings.promptForWorkNoteOnStop {
            pendingNoteLogs.append(contentsOf: openLogs)
        }

        idleStoppedProjectIDs = stoppedIDs
        idleStoppedProjectNames = Array(
            Set(openLogs.compactMap { $0.project?.name })
        ).sorted()
        if settings.idleAlertEnabled {
            showIdleStopAlert()
        } else if settings.promptForWorkNoteOnStop {
            showWorkNotePrompt()
        }
    }

    // MARK: - アイドル停止通知

    /// アイドル自動停止後、計測を再開する。
    func resumeAfterIdle() {
        guard let context, !idleStoppedProjectIDs.isEmpty else { return }
        let ids = idleStoppedProjectIDs
        let descriptor = FetchDescriptor<Project>()
        let projects = (try? context.fetch(descriptor)) ?? []
        for project in projects where ids.contains(project.id) {
            start(project)
        }
        dismissIdleNotification()
    }

    /// アイドル停止通知を閉じる。
    func dismissIdleNotification() {
        idleStoppedProjectIDs = []
        idleStoppedProjectNames = []
        idleAlertPanel?.close()
        idleAlertPanel = nil
    }

    // MARK: - 作業内容プロンプト

    func saveWorkNotes(_ notes: [String]) {
        let trimmed = notes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for log in pendingNoteLogs {
            log.notes = trimmed
        }
        if !pendingNoteLogs.isEmpty { save() }
        pendingNoteLogs = []
        dismissWorkNotePrompt()
    }

    func skipWorkNotes() {
        pendingNoteLogs = []
        dismissWorkNotePrompt()
    }

    private func dismissWorkNotePrompt() {
        workNotePanel?.close()
        workNotePanel = nil
    }

    private func showWorkNotePrompt() {
        if let existing = workNotePanel {
            existing.close()
            workNotePanel = nil
        }
        guard let context else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 350),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "作業内容を記録"
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        centerPanelOnCursorScreen(panel)

        let view = WorkNotePromptView(engine: self)
            .modelContainer(context.container)
        panel.contentView = NSHostingView(rootView: view)

        workNotePanel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func showIdleStopAlert() {
        if let existing = idleAlertPanel {
            existing.close()
            idleAlertPanel = nil
        }

        let panelHeight: CGFloat = settings.promptForWorkNoteOnStop ? 420 : 280
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: panelHeight),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "タイマー自動停止"
        panel.level = .screenSaver
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        centerPanelOnCursorScreen(panel)

        guard let context else { return }
        let alertView = IdleStopAlertView(engine: self)
            .modelContainer(context.container)
        panel.contentView = NSHostingView(rootView: alertView)

        idleAlertPanel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func centerPanelOnCursorScreen(_ panel: NSPanel) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        guard let screen else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let originX = screenFrame.midX - panelSize.width / 2
        let originY = screenFrame.midY - panelSize.height / 2
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    // MARK: - 内部処理

    private func fetchOpenLogs() -> [TimeLog] {
        guard let context else { return [] }
        // オプショナルに対する #Predicate は SwiftData でトラップし得るため、
        // 全件取得してメモリ上でフィルタする（計測中ログは多くないため問題ない）。
        let all = (try? context.fetch(FetchDescriptor<TimeLog>())) ?? []
        return all.filter { $0.endDate == nil }
    }

    /// 前回セッションの開きっぱなしのログを開始時刻で閉じる（時間を捏造しない）。
    private func closeOrphanedLogs() {
        let openLogs = fetchOpenLogs()
        guard !openLogs.isEmpty else { return }
        for log in openLogs {
            log.endDate = log.startDate
        }
        save()
    }

    private func refreshRunningState() {
        let openLogs = fetchOpenLogs()

        var startDates: [UUID: Date] = [:]
        for log in openLogs {
            guard let id = log.project?.id else { continue }
            startDates[id] = min(startDates[id] ?? log.startDate, log.startDate)
        }
        runningStartDates = startDates

        var seen = Set<UUID>()
        let runningProjects = openLogs
            .compactMap { $0.project }
            .sorted { $0.sortOrder < $1.sortOrder }
            .filter { seen.insert($0.id).inserted }
        runningProjectIDs = seen
        runningColorHexes = runningProjects.map(\.colorHex)
    }

    private func save() {
        try? context?.save()
    }
}
