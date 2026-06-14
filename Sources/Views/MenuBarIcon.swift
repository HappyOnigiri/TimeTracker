import SwiftUI

/// メニューバーのステータスアイコンを生成する。
///
/// - 測定中: 測定中プロジェクトの色のストップウォッチを横に並べて表示（複数同時測定に対応）。
/// - 全停止中: 色なし（テンプレート）のストップウォッチのみを表示する。
///
/// 色を確実に反映させるため、色付き時は `ImageRenderer` でビットマップ化し
/// `isTemplate = false` の `NSImage` を返す（テンプレート画像は単色化されるため）。
@MainActor
enum MenuBarIcon {
    /// アイコンの基準フォントサイズ（ポイント）。
    private static let symbolPointSize: CGFloat = 14

    static func image(forColorHexes hexes: [String]) -> NSImage {
        guard !hexes.isEmpty else {
            let image = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "全停止中") ?? NSImage()
            image.isTemplate = true
            return image
        }
        let renderer = ImageRenderer(content: iconStack(hexes))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else {
            let fallback = NSImage(systemSymbolName: "stopwatch.fill", accessibilityDescription: "測定中") ?? NSImage()
            return fallback
        }
        image.isTemplate = false
        return image
    }

    private static func iconStack(_ hexes: [String]) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(hexes.enumerated()), id: \.offset) { _, hex in
                Image(systemName: "stopwatch.fill")
                    .foregroundStyle(Color(hex: hex) ?? .gray)
            }
        }
        .font(.system(size: symbolPointSize))
    }
}
