import Foundation
import SwiftData

/// 1 回の計測区間。`endDate == nil` の間は計測中を表す。
@Model
final class TimeLog {
    var id: UUID = UUID()
    var startDate: Date = Date()
    /// 終了時刻。`nil` の間は計測中。
    var endDate: Date?
    var project: Project?
    var notes: [String] = []

    init(project: Project?, startDate: Date = Date(), endDate: Date? = nil, notes: [String] = []) {
        self.id = UUID()
        self.project = project
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
    }

    var isRunning: Bool { endDate == nil }

    /// 計測時間（秒）。計測中の場合は現在時刻までの経過時間。
    var duration: TimeInterval {
        (endDate ?? Date()).timeIntervalSince(startDate)
    }

    /// 指定した時刻で固定した計測時間（テスト・集計の決定性のため）。
    func duration(asOf now: Date) -> TimeInterval {
        (endDate ?? now).timeIntervalSince(startDate)
    }
}
