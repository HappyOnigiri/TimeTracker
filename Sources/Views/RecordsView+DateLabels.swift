import Foundation

/// RecordsView の月境界の算出と日本式の日付ラベル。
extension RecordsView {
    /// 今月の 1 日 0:00。
    static var currentMonthStart: Date {
        monthStart(for: Date())
    }

    /// 指定日が属する月の 1 日 0:00。
    static func monthStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    /// 「2026年6月」の日本式月ラベル。
    static func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    /// 「6月15日(日)」の日本式日付ラベル。
    static func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }
}
