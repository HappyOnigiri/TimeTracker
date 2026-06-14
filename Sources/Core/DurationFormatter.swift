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

    /// グラフ軸用に時間（小数）へ変換する。
    static func hours(from seconds: TimeInterval) -> Double {
        seconds / 3600
    }
}
