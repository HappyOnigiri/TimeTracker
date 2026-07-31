import Foundation

enum WorkNoteSuggestions {
    /// 最終使用日の新しい順に作業内容の候補を返す。`limit` で件数を絞る。
    static func candidates(from logs: [TimeLog], limit: Int = 20) -> [String] {
        var latestDate: [String: Date] = [:]
        for log in logs {
            let refDate = log.endDate ?? log.startDate
            for note in log.notes {
                let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                latestDate[trimmed] = max(latestDate[trimmed] ?? .distantPast, refDate)
            }
        }
        return latestDate
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key)
    }
}
