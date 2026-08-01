import AppKit
import UniformTypeIdentifiers

/// NSSavePanel を用いて CSV をユーザー選択先へ保存する（App Sandbox 準拠）。
@MainActor
enum CSVExportService {
    enum ExportResult: Equatable {
        case saved(URL)
        case cancelled
        case failed(String)
    }

    static func export(
        logs: [TimeLog],
        clipTo range: ClosedRange<Date>? = nil,
        suggestedName: String = "timelogs.csv",
        locale: Locale = .current
    ) -> ExportResult {
        save(csv: CSVExporter.makeCSV(logs: logs, clipTo: range, locale: locale), suggestedName: suggestedName)
    }

    static func exportNoteSummary(
        totals: [NoteTotal],
        suggestedName: String = "note-summary.csv",
        locale: Locale = .current
    ) -> ExportResult {
        save(csv: CSVExporter.makeNoteSummaryCSV(totals: totals, locale: locale), suggestedName: suggestedName)
    }

    static func exportDailyWork(
        summaries: [DailyWorkSummary],
        calendar: Calendar = .current,
        suggestedName: String = "daily-work.csv",
        locale: Locale = .current
    ) -> ExportResult {
        save(csv: CSVExporter.makeDailyWorkCSV(summaries: summaries, calendar: calendar, locale: locale),
             suggestedName: suggestedName)
    }

    private static func save(csv: String, suggestedName: String) -> ExportResult {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return .cancelled
        }
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return .saved(url)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
