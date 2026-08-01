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
    @ObservationIgnored private var retroactiveStartPanel: NSPanel?

    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var settings = AppSettings()
    @ObservationIgnored private var idleTimer: Timer?
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?

    /// アイドル判定の監視間隔（秒）。
    private let idlePollInterval: TimeInterval = 5

    var isAnyRunning: Bool { !runningProjectIDs.isEmpty }

    /// View 層から ModelContext を受け取って初期化する。
    /// 前回セッションでクラッシュ等により開きっぱなしのログがあれば閉じる。
    func configure(context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        closeOrphanedLogs()
        refreshRunningState()
        startIdleMonitoring()
        observeTermination()
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
        recordHeartbeat()
        refrontIdleAlertIfNeeded()
        checkIdle()
    }

    private func refrontIdleAlertIfNeeded() {
        guard let panel = idleAlertPanel else { return }
        let idleSeconds = IdleDetector.secondsSinceLastInput()
        guard idleSeconds < settings.idleThresholdSeconds else { return }
        FloatingPanel.center(panel)
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

    fileprivate func dismissWorkNotePrompt() {
        workNotePanel?.close()
        workNotePanel = nil
    }

    // MARK: - 異常終了への備え

    /// アプリ終了時に計測中のログを終了時刻で閉じる。
    ///
    /// 閉じずに終了すると開きっぱなしのログが残り、次回起動時に `closeOrphanedLogs()`
    /// へ回ってしまう。終了処理中はパネルを出せないため作業内容の入力は求めない。
    private func observeTermination() {
        guard terminationObserver == nil else { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // 終了処理中は Task のスケジュールが実行される保証がないため同期的に停止する。
            MainActor.assumeIsolated {
                self?.stopAll()
            }
        }
    }

    /// 計測中は生存時刻を記録し続ける。
    /// クラッシュ・強制終了・電源断で終了処理が走らなくても、
    /// 次回起動時にここまでの計測を復元できる。
    private func recordHeartbeat(now: Date = Date()) {
        guard isAnyRunning else { return }
        settings.recordHeartbeat(now)
    }

    // MARK: - 内部処理

    private func fetchOpenLogs() -> [TimeLog] {
        guard let context else { return [] }
        // オプショナルに対する #Predicate は SwiftData でトラップし得るため、
        // 全件取得してメモリ上でフィルタする（計測中ログは多くないため問題ない）。
        let all = (try? context.fetch(FetchDescriptor<TimeLog>())) ?? []
        return all.filter { $0.endDate == nil }
    }

    /// 前回セッションの開きっぱなしのログを、最後に生存を記録した時刻で閉じる。
    ///
    /// heartbeat がなければ開始時刻で閉じる（時間を捏造しない）。
    /// heartbeat は最大 `idlePollInterval` 秒ぶん古いだけなので、
    /// クラッシュしても計測はほぼ失われない。
    private func closeOrphanedLogs(now: Date = Date()) {
        let openLogs = fetchOpenLogs()
        guard !openLogs.isEmpty else { return }
        let heartbeat = settings.lastHeartbeat
        for log in openLogs {
            log.endDate = min(now, max(heartbeat ?? log.startDate, log.startDate))
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
        guard let context else { return }
        do {
            try context.save()
        } catch {
            // 保存失敗を握り潰すと、計測が記録されないまま UI 上は正常に見えてしまう。
            AppLog.persistence.error("計測ログの保存に失敗しました: \(error, privacy: .public)")
            assertionFailure("計測ログの保存に失敗しました: \(error)")
        }
    }
}

extension TimerEngine {
    enum RetroactiveStartResult: Equatable {
        case started
        case futureStartDate
        case alreadyRunning
        case anotherProjectIsRunning
        case engineNotConfigured
    }

    /// 指定した過去日時からプロジェクトの計測を開始する。
    /// 通常開始と異なり、同時測定が無効な場合も既存ログを停止せず競合として拒否する。
    @discardableResult
    func startRetroactively(
        _ project: Project,
        at startDate: Date,
        now: Date = Date()
    ) -> RetroactiveStartResult {
        guard startDate <= now else { return .futureStartDate }
        guard let context else { return .engineNotConfigured }

        let openLogs = fetchOpenLogs()
        guard !openLogs.contains(where: { $0.project?.id == project.id }) else {
            return .alreadyRunning
        }
        guard settings.allowConcurrentTracking || openLogs.isEmpty else {
            return .anotherProjectIsRunning
        }

        context.insert(TimeLog(project: project, startDate: startDate))
        save()
        refreshRunningState()
        return .started
    }
}

// MARK: - パネル表示

extension TimerEngine {
    func showRetroactiveStartPanel(for project: Project) {
        retroactiveStartPanel?.close()
        let locale = settings.displayLanguage.locale
        let panel = FloatingPanel.make(
            size: NSSize(width: 380, height: 300),
            title: L10n.string("開始時刻を指定", locale: locale)
        )
        let view = RetroactiveStartView(
            project: project, engine: self,
            onDismiss: { [weak self] in self?.dismissRetroactiveStartPanel() }
        )
        panel.contentView = NSHostingView(rootView: view.environment(\.locale, locale))
        retroactiveStartPanel = panel
        FloatingPanel.present(panel)
    }

    func dismissRetroactiveStartPanel() {
        retroactiveStartPanel?.close()
        retroactiveStartPanel = nil
    }

    fileprivate func showWorkNotePrompt() {
        workNotePanel?.close()
        guard let context else { return }
        let locale = settings.displayLanguage.locale
        let panel = FloatingPanel.make(
            size: NSSize(width: 480, height: 350),
            title: L10n.string("作業内容を記録", locale: locale),
            styleMask: [.titled, .resizable]
        )
        let view = WorkNotePromptView(engine: self)
            .environment(\.locale, locale)
            .modelContainer(context.container)
        panel.contentView = NSHostingView(rootView: view)
        workNotePanel = panel
        FloatingPanel.present(panel)
    }

    fileprivate func showIdleStopAlert() {
        idleAlertPanel?.close()
        guard let context else { return }
        let locale = settings.displayLanguage.locale
        let panelHeight: CGFloat = settings.promptForWorkNoteOnStop ? 420 : 280
        let panel = FloatingPanel.make(
            size: NSSize(width: 480, height: panelHeight),
            title: L10n.string("タイマー自動停止", locale: locale), level: .screenSaver,
            styleMask: [.titled, .resizable]
        )
        let view = IdleStopAlertView(engine: self)
            .environment(\.locale, locale)
            .modelContainer(context.container)
        panel.contentView = NSHostingView(rootView: view)
        idleAlertPanel = panel
        FloatingPanel.present(panel)
    }
}
