import Foundation
import Observation
import SwiftData

/// PCのアクティブ時間を自動記録するサービス。
/// IdleDetector を定期的にポーリングし、入力があればセッションを開始、
/// アイドルが閾値を超えたらセッションを終了する。
@MainActor
@Observable
final class ActiveTimeTracker {
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var pollTimer: Timer?

    /// アイドルとみなす閾値（秒）。この秒数入力がなければセッション終了。
    private let idleThreshold: TimeInterval = 120

    /// この秒数以内に再びアクティブになったら、前のセッションに統合する。
    private let mergeThreshold: TimeInterval = 300

    /// ポーリング間隔（秒）。
    private let pollInterval: TimeInterval = 10

    func configure(context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        closeOrphanedSessions()
        startPolling()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func poll(now: Date = Date(), idleSeconds: TimeInterval = IdleDetector.secondsSinceLastInput()) {
        guard let context else { return }
        let openSession = fetchOpenSession()

        if idleSeconds < idleThreshold {
            if openSession == nil {
                // 直近のセッションが mergeThreshold 以内に終了していれば再開する
                if let recent = fetchMostRecentClosed(),
                   let end = recent.endDate,
                   now.timeIntervalSince(end) <= mergeThreshold {
                    recent.endDate = nil
                } else {
                    context.insert(ActiveSession(startDate: now))
                }
                try? context.save()
            }
        } else {
            if let session = openSession {
                let lastInput = now.addingTimeInterval(-idleSeconds)
                session.endDate = max(lastInput, session.startDate)
                try? context.save()
            }
        }
    }

    private func fetchOpenSession() -> ActiveSession? {
        guard let context else { return nil }
        let all = (try? context.fetch(FetchDescriptor<ActiveSession>())) ?? []
        return all.first { $0.endDate == nil }
    }

    private func fetchMostRecentClosed() -> ActiveSession? {
        guard let context else { return nil }
        var descriptor = FetchDescriptor<ActiveSession>(
            sortBy: [SortDescriptor(\ActiveSession.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let results = (try? context.fetch(descriptor)) ?? []
        return results.first { $0.endDate != nil }
    }

    /// 前回セッションの開きっぱなしのログを最終入力時刻で閉じる。
    private func closeOrphanedSessions() {
        guard let context else { return }
        let idleSeconds = IdleDetector.secondsSinceLastInput()
        let lastInput = Date().addingTimeInterval(-idleSeconds)
        let all = (try? context.fetch(FetchDescriptor<ActiveSession>())) ?? []
        let open = all.filter { $0.endDate == nil }
        for session in open {
            session.endDate = max(lastInput, session.startDate)
        }
        if !open.isEmpty { try? context.save() }
    }
}
