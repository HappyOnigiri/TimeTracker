import Foundation

/// タイムログを CSV 文字列へ変換する純粋ロジック。
enum CSVExporter {
    static let header = "project,start,end,duration_seconds"

    /// RFC 4180 準拠の CSV を生成する。日時は ISO 8601。計測中のログは除外する。
    static func makeCSV(logs: [TimeLog], now: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let sorted = logs
            .filter { $0.endDate != nil }
            .sorted { $0.startDate < $1.startDate }

        var rows = [header]
        for log in sorted {
            guard let end = log.endDate else { continue }
            let name = log.project?.name ?? "(削除済み)"
            let duration = Int(end.timeIntervalSince(log.startDate).rounded())
            let fields = [
                escape(name),
                formatter.string(from: log.startDate),
                formatter.string(from: end),
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
