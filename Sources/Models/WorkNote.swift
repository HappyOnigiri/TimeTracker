import Foundation
import SwiftData

/// 入力候補とプロジェクト関連を保持する作業内容カタログ。
@Model
final class WorkNote {
    var id: UUID = UUID()
    /// 前後の空白を除いた作業内容。比較規則は `WorkNoteRenaming.key` と共通。
    var text: String = ""
    var projects: [Project] = []

    init(text: String, projects: [Project] = []) {
        self.id = UUID()
        self.text = WorkNoteRenaming.key(text)
        self.projects = projects
    }
}
