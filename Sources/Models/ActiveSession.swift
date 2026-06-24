import Foundation
import SwiftData

/// PCがアクティブだった期間。キーボード/マウス入力が検出されている間を記録する。
@Model
final class ActiveSession {
    var id: UUID = UUID()
    var startDate: Date = Date()
    /// 終了時刻。`nil` の間はアクティブ継続中。
    var endDate: Date?

    init(startDate: Date = Date(), endDate: Date? = nil) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
    }

    var isActive: Bool { endDate == nil }

    var duration: TimeInterval {
        (endDate ?? Date()).timeIntervalSince(startDate)
    }
}
