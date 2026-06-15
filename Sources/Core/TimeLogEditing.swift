import Foundation
import SwiftData

/// TimeLog の追加・更新・複製・削除をまとめた共有ヘルパー。
/// リスト編集（RecordsView）とタイムライン編集（DayTimelineView）の双方から利用する。
enum TimeLogEditing {
    /// 新規記録を追加する。
    static func add(project: Project, start: Date, end: Date, in context: ModelContext) {
        context.insert(TimeLog(project: project, startDate: start, endDate: end))
        try? context.save()
    }

    /// 既存記録のプロジェクト・開始・終了を更新する。
    static func update(_ log: TimeLog, project: Project, start: Date, end: Date, in context: ModelContext) {
        log.project = project
        log.startDate = start
        log.endDate = end
        try? context.save()
    }

    /// 既存記録の開始・終了のみ更新する（タイムラインのドラッグ確定など）。
    static func updateTimes(_ log: TimeLog, start: Date, end: Date, in context: ModelContext) {
        log.startDate = start
        log.endDate = end
        try? context.save()
    }

    /// 同プロジェクト・同時間帯で記録を複製する。
    static func duplicate(_ log: TimeLog, in context: ModelContext) {
        context.insert(TimeLog(project: log.project, startDate: log.startDate, endDate: log.endDate))
        try? context.save()
    }

    /// 記録を削除する。
    static func delete(_ log: TimeLog, in context: ModelContext) {
        context.delete(log)
        try? context.save()
    }
}
