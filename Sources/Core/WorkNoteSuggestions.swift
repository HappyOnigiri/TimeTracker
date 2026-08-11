import Foundation

enum WorkNoteSuggestions {
    /// 現在のプロジェクトに関連し、直近1か月以内に利用された候補を返す。
    /// `showAll` では関連・利用日時・件数上限を適用しない。
    static func candidates(
        from workNotes: [WorkNote],
        logs: [TimeLog],
        projectIDs: Set<UUID>,
        showAll: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 20
    ) -> [String] {
        let relevantLogs = showAll ? logs : logs.filter { log in
            log.project.map { projectIDs.contains($0.id) } ?? false
        }
        let latestDate = latestDates(in: relevantLogs)
        let cutoff = calendar.date(byAdding: .month, value: -1, to: now) ?? .distantPast
        let filtered = workNotes.filter {
            shouldInclude($0, latestDate: latestDate, projectIDs: projectIDs, showAll: showAll, cutoff: cutoff)
        }
        let values = filtered
            .sorted { isOrdered($0, before: $1, latestDate: latestDate) }
            .map { WorkNoteRenaming.key($0.text) }
        return showAll ? values : Array(values.prefix(limit))
    }

    private static func latestDates(in logs: [TimeLog]) -> [String: Date] {
        var result: [String: Date] = [:]
        for log in logs {
            let refDate = log.endDate ?? log.startDate
            for note in log.notes {
                let text = WorkNoteRenaming.key(note)
                guard !text.isEmpty else { continue }
                result[text] = max(result[text] ?? .distantPast, refDate)
            }
        }
        return result
    }

    private static func shouldInclude(
        _ item: WorkNote,
        latestDate: [String: Date],
        projectIDs: Set<UUID>,
        showAll: Bool,
        cutoff: Date
    ) -> Bool {
        let text = WorkNoteRenaming.key(item.text)
        guard !text.isEmpty else { return false }
        if showAll { return true }
        guard item.projects.contains(where: { projectIDs.contains($0.id) }) else { return false }
        return latestDate[text].map { $0 > cutoff } ?? false
    }

    private static func isOrdered(
        _ lhs: WorkNote,
        before rhs: WorkNote,
        latestDate: [String: Date]
    ) -> Bool {
        let lhsText = WorkNoteRenaming.key(lhs.text)
        let rhsText = WorkNoteRenaming.key(rhs.text)
        switch (latestDate[lhsText], latestDate[rhsText]) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate > rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhsText < rhsText
        }
    }
}
