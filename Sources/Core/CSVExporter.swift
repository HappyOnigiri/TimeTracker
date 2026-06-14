import Foundation

/// タイムログを CSV 文字列へ変換する純粋ロジック。
enum CSVExporter {
    static let header = "project,start,end,duration_seconds"

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
            let fields = [
                escape(name),
                formatter.string(from: clippedStart),
                formatter.string(from: clippedEnd),
                String(duration)
            ]
            rows.append(fields.joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    /// カンマ・引用符・改行を含む場合はダブルクォートで囲み、内部の `"` を二重化する。
    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
