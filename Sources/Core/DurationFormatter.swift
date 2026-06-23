import Foundation

enum DurationFormatter {
    /// 秒数を "1時間23分" 形式に整形する。
    static func string(from seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }
        return "\(minutes)分"
    }

    /// 経過時間を時計形式に整形する。1 時間以上は "1:02:03"、未満は "02:03"。
    static func clockString(from seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// グラフ軸用に時間（小数）へ変換する。
    static func hours(from seconds: TimeInterval) -> Double {
        seconds / 3600
    }

    /// "7.1h" 形式のコンパクトな時間表記。
    static func compactHours(from seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        return String(format: "%.1fh", hours)
    }
}
