import Foundation

/// プロジェクト別の合計稼働時間。
struct ProjectTotal: Identifiable {
    let projectID: UUID
    let name: String
    let colorHex: String
    let seconds: TimeInterval
    var id: UUID { projectID }
}

/// 1 日 × プロジェクトごとの稼働時間。
struct DailyDuration: Identifiable {
    let day: Date
    let projectID: UUID
    let name: String
    let colorHex: String
    let seconds: TimeInterval
    var id: String { "\(projectID.uuidString)-\(day.timeIntervalSince1970)" }
}

/// TimeLog 群を期間で切り出し、合計/日次に集計する純粋ロジック。
enum ReportAggregator {
    /// 集計途中の値を保持する内部アキュムレータ。
    private struct Accumulator {
        let projectID: UUID
        let name: String
        let colorHex: String
        var day: Date = .distantPast
        var seconds: TimeInterval = 0
    }

    /// プロジェクト別の合計稼働秒数を、稼働時間の降順で返す。
    static func projectTotals(
        logs: [TimeLog],
        in range: ClosedRange<Date>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ProjectTotal] {
        var totals: [UUID: Accumulator] = [:]
        for log in logs {
            guard let project = log.project else { continue }
            let seconds = clippedDuration(for: log, in: range, now: now)
            guard seconds > 0 else { continue }
            var entry = totals[project.id]
                ?? Accumulator(projectID: project.id, name: project.name, colorHex: project.colorHex)
            entry.seconds += seconds
            totals[project.id] = entry
        }
        return totals.values
            .map { ProjectTotal(projectID: $0.projectID, name: $0.name, colorHex: $0.colorHex, seconds: $0.seconds) }
            .sorted { $0.seconds > $1.seconds }
    }

    /// 1 日ごと × プロジェクトの稼働秒数を、日付昇順で返す。
    static func dailyDurations(
        logs: [TimeLog],
        in range: ClosedRange<Date>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyDuration] {
        var grouped: [String: Accumulator] = [:]
        for log in logs {
            guard let project = log.project else { continue }
            for segment in dailySegments(for: log, in: range, now: now, calendar: calendar) {
                let key = "\(project.id.uuidString)-\(segment.day.timeIntervalSince1970)"
                var entry = grouped[key] ?? Accumulator(
                    projectID: project.id,
                    name: project.name,
                    colorHex: project.colorHex,
                    day: segment.day
                )
                entry.seconds += segment.seconds
                grouped[key] = entry
            }
        }
        return grouped.values
            .map {
                DailyDuration(day: $0.day, projectID: $0.projectID,
                              name: $0.name, colorHex: $0.colorHex, seconds: $0.seconds)
            }
            .sorted { $0.day < $1.day }
    }

    // MARK: - 内部

    /// 期間でクリップした合計秒数。
    private static func clippedDuration(for log: TimeLog, in range: ClosedRange<Date>, now: Date) -> TimeInterval {
        let start = max(log.startDate, range.lowerBound)
        let end = min(log.endDate ?? now, range.upperBound)
        return max(0, end.timeIntervalSince(start))
    }

    /// 期間でクリップしつつ、日付境界で分割した (日, 秒数) を返す。
    private static func dailySegments(
        for log: TimeLog,
        in range: ClosedRange<Date>,
        now: Date,
        calendar: Calendar
    ) -> [(day: Date, seconds: TimeInterval)] {
        let start = max(log.startDate, range.lowerBound)
        let end = min(log.endDate ?? now, range.upperBound)
        guard end > start else { return [] }

        var segments: [(Date, TimeInterval)] = []
        var cursor = start
        while cursor < end {
            let dayStart = calendar.startOfDay(for: cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            let segmentEnd = min(nextDay, end)
            segments.append((dayStart, segmentEnd.timeIntervalSince(cursor)))
            cursor = segmentEnd
        }
        return segments
    }
}
