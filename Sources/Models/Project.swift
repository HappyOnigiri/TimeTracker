import SwiftData
import SwiftUI

/// 計測対象のプロジェクト。
@Model
final class Project {
    /// 安定した識別子（CSV やレポート集計のキーに使用）。
    var id: UUID = UUID()
    var name: String = ""
    /// 一覧やグラフでの色分け用 16 進カラー（例: "#FF8800"）。
    var colorHex: String = "#4E9BFF"
    var createdAt: Date = Date()
    /// 一覧での並び順。
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \TimeLog.project)
    var logs: [TimeLog] = []

    init(name: String, colorHex: String = "#4E9BFF", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.logs = []
    }

    /// 現在計測中（終了していないログが存在する）か。
    var isRunning: Bool {
        logs.contains { $0.endDate == nil }
    }

    var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }
}
