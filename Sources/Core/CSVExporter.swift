import Foundation

/// タイムログを CSV 文字列へ変換する純粋ロジック。
enum CSVExporter {
    static let header = "project,start,end,duration_seconds,notes"

    /// RFC 4180 準拠の CSV を生成する。日時は ISO 8601。計測中のログは除外する。
    ///
    /// `clipTo` を指定した場合、各ログの開始/終了をその範囲にクリップし、
    /// duration を再計算する。範囲と重ならないログは除外する。
    static func makeCSV(logs: [TimeLog], clipTo range: ClosedRange<Date>? = nil, now: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let sorted = logs
            .filter { $0.endDate != nil }
            .sorted { $0.startDate < $1.startDate }

        var rows = [header]
        for log in sorted {
            guard let end = log.endDate else { continue }
            let start = log.startDate
            let clippedStart = range.map { max(start, $0.lowerBound) } ?? start
            let clippedEnd = range.map { min(end, $0.upperBound) } ?? end
            guard clippedEnd > clippedStart else { continue }
            let name = log.project?.name ?? "(削除済み)"
            let duration = Int(clippedEnd.timeIntervalSince(clippedStart).rounded())
            let notesField = log.notes.joined(separator: "; ")
            let fields = [
                escape(name),
                formatter.string(from: clippedStart),
                formatter.string(from: clippedEnd),
                String(duration),
                escape(notesField)
            ]
            rows.append(fields.joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    /// 作業内容別の集計 CSV を生成する。
    static func makeNoteSummaryCSV(totals: [NoteTotal]) -> String {
        var rows = ["note,duration_seconds,duration_hours"]
        for total in totals {
            let fields = [
                escape(total.note),
                String(Int(total.seconds)),
                String(format: "%.1f", total.seconds / 3600)
            ]
            rows.append(fields.joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    /// CSV フィールドを安全化する。
    ///
    /// 1. 先頭が `=`/`+`/`-`/`@`/タブ/復帰の場合、表計算ソフトが数式として解釈する
    ///    （CSV インジェクション, CWE-1236）のを防ぐため先頭にシングルクォートを付す。
    /// 2. カンマ・引用符・改行を含む場合はダブルクォートで囲み、内部の `"` を二重化する。
    private static func escape(_ field: String) -> String {
        var value = field
        if let first = value.first, "=+-@\t\r".contains(first) {
            value = "'" + value
        }
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
