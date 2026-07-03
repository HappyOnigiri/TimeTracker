import Foundation

enum WorkNoteSuggestions {
    static func candidates(from logs: [TimeLog]) -> [String] {
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
            .map(\.key)
    }
}
