import Foundation

extension Calendar {
    /// JST 固定のカレンダー。
    ///
    /// 日付別の集計・出力は、実行環境のタイムゾーン設定に依存せず常に日本時間の
    /// 日付境界で区切る必要があるため、`.current` ではなくこちらを使う。
    static var jst: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let timeZone = TimeZone(identifier: "Asia/Tokyo") {
            calendar.timeZone = timeZone
        }
        return calendar
    }
}
