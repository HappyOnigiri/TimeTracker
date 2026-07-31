import Foundation
import SwiftData

/// README 撮影用のアプリにだけ投入するサンプルデータ。
@MainActor
enum ScreenshotSampleData {
    struct Entry {
        let projectIndex: Int
        let day: Int
        let startHour: Int
        let startMinute: Int
        let durationMinutes: Int
        let notes: [String]
    }

    static let projects = [
        (name: "Webサイト改修", colorHex: "#4E9BFF"),
        (name: "モバイルアプリ", colorHex: "#FF8A4C"),
        (name: "運用・サポート", colorHex: "#56B37F")
    ]

    static let entries = [
        Entry(projectIndex: 0, day: 2, startHour: 9, startMinute: 15, durationMinutes: 165, notes: ["画面設計"]),
        Entry(projectIndex: 1, day: 2, startHour: 13, startMinute: 0, durationMinutes: 210, notes: ["実装"]),
        Entry(projectIndex: 2, day: 3, startHour: 10, startMinute: 0, durationMinutes: 90, notes: ["問い合わせ対応"]),
        Entry(projectIndex: 0, day: 5, startHour: 9, startMinute: 30, durationMinutes: 240, notes: ["実装"]),
        Entry(projectIndex: 1, day: 6, startHour: 10, startMinute: 15, durationMinutes: 195, notes: ["画面設計"]),
        Entry(projectIndex: 2, day: 6, startHour: 15, startMinute: 0, durationMinutes: 75, notes: ["定例ミーティング"]),
        Entry(projectIndex: 0, day: 9, startHour: 9, startMinute: 0, durationMinutes: 180, notes: ["レビュー"]),
        Entry(projectIndex: 1, day: 10, startHour: 13, startMinute: 15, durationMinutes: 255, notes: ["実装"]),
        Entry(projectIndex: 2, day: 12, startHour: 10, startMinute: 0, durationMinutes: 120, notes: ["問い合わせ対応"]),
        Entry(projectIndex: 0, day: 13, startHour: 9, startMinute: 45, durationMinutes: 225, notes: ["実装", "レビュー"]),
        Entry(projectIndex: 1, day: 16, startHour: 10, startMinute: 0, durationMinutes: 270, notes: ["実装"]),
        Entry(projectIndex: 2, day: 17, startHour: 14, startMinute: 0, durationMinutes: 105, notes: ["定例ミーティング"]),
        Entry(projectIndex: 0, day: 19, startHour: 9, startMinute: 15, durationMinutes: 300, notes: ["画面設計"]),
        Entry(projectIndex: 1, day: 20, startHour: 13, startMinute: 0, durationMinutes: 210, notes: ["レビュー"]),
        Entry(projectIndex: 2, day: 23, startHour: 10, startMinute: 30, durationMinutes: 135, notes: ["問い合わせ対応"]),
        Entry(projectIndex: 0, day: 24, startHour: 9, startMinute: 0, durationMinutes: 255, notes: ["実装"]),
        Entry(projectIndex: 1, day: 26, startHour: 10, startMinute: 15, durationMinutes: 240, notes: ["画面設計", "実装"]),
        Entry(projectIndex: 2, day: 27, startHour: 14, startMinute: 15, durationMinutes: 90, notes: ["定例ミーティング"])
    ]

    nonisolated static func sampleMonth(containing now: Date, calendar: Calendar = .current) -> Date {
        let currentMonthComponents = calendar.dateComponents([.year, .month], from: now)
        let currentMonth = calendar.date(from: currentMonthComponents) ?? calendar.startOfDay(for: now)
        return calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    nonisolated static func initialMonth(fallback: Date) -> Date {
#if SCREENSHOT_BUILD
        sampleMonth(containing: Date())
#else
        fallback
#endif
    }

    static func replaceAll(
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        try removeExistingData(from: context)

        let models = projects.enumerated().map { index, item in
            Project(name: item.name, colorHex: item.colorHex, sortOrder: index)
        }
        models.forEach(context.insert)

        let month = sampleMonth(containing: now, calendar: calendar)
        for entry in entries {
            guard let startDate = calendar.date(
                bySettingHour: entry.startHour,
                minute: entry.startMinute,
                second: 0,
                of: calendar.date(byAdding: .day, value: entry.day - 1, to: month) ?? month
            ) else { continue }
            let endDate = startDate.addingTimeInterval(TimeInterval(entry.durationMinutes * 60))
            context.insert(TimeLog(
                project: models[entry.projectIndex],
                startDate: startDate,
                endDate: endDate,
                notes: entry.notes
            ))
            context.insert(ActiveSession(startDate: startDate, endDate: endDate))
        }

        try context.save()
    }

    private static func removeExistingData(from context: ModelContext) throws {
        for log in try context.fetch(FetchDescriptor<TimeLog>()) {
            context.delete(log)
        }
        for session in try context.fetch(FetchDescriptor<ActiveSession>()) {
            context.delete(session)
        }
        for project in try context.fetch(FetchDescriptor<Project>()) {
            context.delete(project)
        }
        try context.save()
    }
}
