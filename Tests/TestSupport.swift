import Foundation
import SwiftData
@testable import TimeTracker

/// テスト用ユーティリティ。
enum TestSupport {
    /// テスト間で共有する単一のインメモリ Container。
    /// テストごとに新しい Container を生成するとプロセス内で SwiftData がトラップするため、
    /// 1 つを共有して各テスト冒頭でデータを全削除する（テストは直列実行）。
    @MainActor
    private static let sharedContainer: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        return try! ModelContainer(
            for: Project.self, TimeLog.self, WorkNote.self, ActiveSession.self,
            configurations: config
        )
    }()

    /// 既存データを消去した、新しいインメモリ ModelContext を返す。
    ///
    /// `mainContext` をテスト間で再利用すると、削除済みモデルの登録状態が残り、
    /// 関係をたどった際に SwiftData の full future backing data でトラップすることがある。
    /// Container だけを共有し、Context はテストごとに作り直す。
    @MainActor
    static func makeContext() throws -> ModelContext {
        let context = ModelContext(sharedContainer)
        // バッチ削除は関係制約に抵触するため、個別に削除する。
        let workNotes = (try? context.fetch(FetchDescriptor<WorkNote>())) ?? []
        for note in workNotes {
            note.projects = []
        }
        try context.save()
        for note in workNotes {
            context.delete(note)
        }
        // 多対多の逆関連を確実に解除してから Project を削除する。
        try context.save()
        for session in (try? context.fetch(FetchDescriptor<ActiveSession>())) ?? [] {
            context.delete(session)
        }
        for log in (try? context.fetch(FetchDescriptor<TimeLog>())) ?? [] {
            context.delete(log)
        }
        for project in (try? context.fetch(FetchDescriptor<Project>())) ?? [] {
            context.delete(project)
        }
        try context.save()
        return context
    }

    /// 共有 Container 内の別 Context に多対多モデルの循環参照を残さないための後処理。
    @MainActor
    static func clearWorkNoteRelationships(in context: ModelContext) {
        for note in (try? context.fetch(FetchDescriptor<WorkNote>())) ?? [] {
            note.projects = []
        }
        try? context.save()
    }

    /// UTC 固定のカレンダー（日付境界の決定性のため）。
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// UTC での日時を生成する。
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return utcCalendar.date(from: components)!
    }
}
