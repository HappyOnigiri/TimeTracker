import Foundation

/// 時刻テキストを Date へ反映するときの判定。
///
/// TextField にフォーカスが残ったまま「保存」「開始」を押しても入力が捨てられないよう、
/// 入力中の 1 文字ごとにこの判定を通して Date を更新する用途で使う。
enum TimeInputCommit {
    enum Outcome: Equatable {
        /// 時刻として解釈でき、現在の値とは違う時刻になった。
        case updated(Date)
        /// 時刻として解釈できたが、現在の値と分単位で同じだった。
        case unchanged
        /// 時刻として解釈できない（"18:" のような入力途中を含む）。
        case invalid
    }

    static func evaluate(
        text: String,
        current: Date,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Outcome {
        guard let parsed = TimeInputParser.parse(text) else { return .invalid }
        let applied = TimeInputParser.applyToDate(parsed, referenceDate: referenceDate, calendar: calendar)
        // 表示は H:mm 精度のため、秒だけの差で Date を書き換えないようにする。
        if calendar.isDate(applied, equalTo: current, toGranularity: .minute) { return .unchanged }
        return .updated(applied)
    }
}
