import Foundation
import Observation
import SwiftData

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

    /// プロジェクトの計測を開始する。同時測定が無効なら他を停止してから開始する。
    func start(_ project: Project, now: Date = Date()) {
        guard let context else { return }
        guard !isRunning(project) else { return }
        if !settings.allowConcurrentTracking {
            stopAll(now: now)
        }
        context.insert(TimeLog(project: project, startDate: now))
        save()
        refreshRunningState()
    }

    /// プロジェクトの計測を停止する。
    func stop(_ project: Project, now: Date = Date()) {
        guard context != nil else { return }
        let targetID = project.id
        let openLogs = fetchOpenLogs().filter { $0.project?.id == targetID }
        for log in openLogs {
            log.endDate = now
        }
        if !openLogs.isEmpty { save() }
        refreshRunningState()
    }

    func toggle(_ project: Project, now: Date = Date()) {
        if isRunning(project) {
            stop(project, now: now)
        } else {
            start(project, now: now)
        }
    }

    /// 稼働中のすべてのタイマーを停止する。
    func stopAll(now: Date = Date()) {
        let openLogs = fetchOpenLogs()
        guard !openLogs.isEmpty else { return }
        for log in openLogs {
            log.endDate = now
        }
        save()
        refreshRunningState()
    }

    // MARK: - アイドル検知

    private func startIdleMonitoring() {
        idleTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: idlePollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdle()
            }
        }
        idleTimer = timer
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
        for log in openLogs {
            log.endDate = max(stopAt, log.startDate)
        }
        save()
        refreshRunningState()
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
        var seen = Set<UUID>()
        let runningProjects = fetchOpenLogs()
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
