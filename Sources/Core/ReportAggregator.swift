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

/// 1 日の稼働時間と、その日に稼働のあった作業内容。
struct DailyWorkSummary: Identifiable {
    /// その日の 0:00（集計に用いたカレンダー基準）。
    let day: Date
    let seconds: TimeInterval
    /// 出現順（ログの開始時刻昇順）に重複を除いた作業内容。
    let notes: [String]
    var id: Date { day }
}

/// 作業内容ごとの合計稼働時間。
struct NoteTotal: Identifiable {
    let note: String
    let seconds: TimeInterval
    var id: String { note }
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

    /// 作業内容（note）ごとの合計稼働秒数を、稼働時間の降順で返す。
    /// 1 ログに複数 note がある場合は note 数で均等割りし、合計が実稼働と一致するようにする。
    static func noteTotals(
        logs: [TimeLog],
        in range: ClosedRange<Date>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [NoteTotal] {
        var totals: [String: TimeInterval] = [:]
        for log in logs {
            let seconds = clippedDuration(for: log, in: range, now: now)
            guard seconds > 0 else { continue }
            let uniqueNotes = Set(
                log.notes
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            )
            if uniqueNotes.isEmpty {
                totals["(未分類)", default: 0] += seconds
            } else {
                let share = seconds / Double(uniqueNotes.count)
                for note in uniqueNotes {
                    totals[note, default: 0] += share
                }
            }
        }
        return totals
            .map { NoteTotal(note: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
    }

    /// 1 日ごとの稼働秒数と作業内容を、日付昇順で返す。
    ///
    /// プロジェクトの区別はせず、その日の稼働を合算する。日付をまたぐログは
    /// 日付境界で分割し、作業内容はまたいだ双方の日に記録する。
    ///
    /// 稼働のない日も 0 秒・作業内容なしの要素として含めるため、返り値は `range` に含まれる
    /// すべての日を隙間なく網羅する（`range` の上限が属する日は、上限がその日の 0:00 のとき
    /// 稼働しうる時間が無いため除く）。
    static func dailyWorkSummaries(
        logs: [TimeLog],
        in range: ClosedRange<Date>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyWorkSummary] {
        var seconds: [Date: TimeInterval] = [:]
        var notes: [Date: [String]] = [:]
        var seenNotes: [Date: Set<String>] = [:]

        for log in logs.sorted(by: { $0.startDate < $1.startDate }) {
            let segments = dailySegments(for: log, in: range, now: now, calendar: calendar)
            guard !segments.isEmpty else { continue }
            let logNotes = log.notes
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            for segment in segments {
                seconds[segment.day, default: 0] += segment.seconds
                var seen = seenNotes[segment.day] ?? []
                for note in logNotes where seen.insert(note).inserted {
                    notes[segment.day, default: []].append(note)
                }
                seenNotes[segment.day] = seen
            }
        }

        return allDays(in: range, calendar: calendar).map { day in
            DailyWorkSummary(day: day, seconds: seconds[day] ?? 0, notes: notes[day] ?? [])
        }
    }

    // MARK: - 内部

    /// 期間に含まれるすべての日の 0:00 を昇順で返す。
    ///
    /// 上限が 0:00 ちょうどの日は、その日に稼働しうる時間が無いため含めない。
    private static func allDays(in range: ClosedRange<Date>, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: range.lowerBound)
        while cursor < range.upperBound {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

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
