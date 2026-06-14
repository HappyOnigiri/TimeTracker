import SwiftUI

extension Color {
    /// "#RRGGBB" 形式の文字列から Color を生成する。
    init?(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt32(string, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

/// プロジェクト作成時に割り当てる既定パレット。
enum ProjectPalette {
    static let colors = [
        "#4E9BFF", "#FF8800", "#34C759", "#FF375F",
        "#AF52DE", "#FFCC00", "#5AC8FA", "#FF6482"
    ]

    /// 並び順に応じてパレットから色を巡回選択する。
    static func color(forIndex index: Int) -> String {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}
