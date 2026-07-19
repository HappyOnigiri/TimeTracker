import AppKit
import SwiftUI
import Testing
@testable import TimeTracker

/// snapPreview をオフスクリーン描画し、点線枠の描画位置を実測する回帰テスト。
/// overlay の暗黙スタックは子同士を中央揃えで合成するため、点線枠と時刻ラベルを
/// Group で重ねると、ラベルより狭い点線枠が右へ押し出される（実測 +22pt ≒ 30分相当）。
@MainActor
struct MonthTimelineSnapPreviewRenderTests {
    @Test("点線枠の左端が時刻ラベルの幅に影響されず localX に一致する")
    func dashedRectLeftEdgeMatchesLocalX() throws {
        let view = MonthTimelineView(
            month: Date(timeIntervalSinceReferenceDate: 0),
            logs: [], projects: [], activeSessions: [],
            pointsPerHour: .constant(48),
            onSelect: { _ in }, onAddLog: { _, _, _ in }
        )
        let blockH = view.laneHeight - view.laneGap
        let localX: CGFloat = 100
        // 30 分ブロック相当（48pt/h で 24pt）。ラベル「14:45–15:15」より確実に狭い幅にする。
        let previewWidth: CGFloat = 24
        let cal = Calendar.current
        let start = try #require(cal.date(from: DateComponents(year: 2026, month: 7, day: 17, hour: 14, minute: 45)))
        let end = try #require(cal.date(from: DateComponents(year: 2026, month: 7, day: 17, hour: 15, minute: 15)))

        // block(for:day:) と同じく、ブロック相当のビューへ topLeading の overlay として合成する。
        // ラベルは y 負方向へオフセットされるためキャンバス外に出て、点線枠だけが計測対象になる。
        let canvas = ZStack(alignment: .topLeading) {
            Color.white
            Color.clear
                .frame(width: 14, height: blockH, alignment: .leading)
                .overlay(alignment: .topLeading) {
                    view.snapPreview(
                        localX: localX, width: previewWidth,
                        snappedStart: start, snappedEnd: end
                    )
                }
        }
        .frame(width: 200, height: blockH, alignment: .topLeading)

        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let minX = try #require(Self.minColoredColumn(in: image))

        // 点線ストローク（線幅 1.5 中央揃え）とアンチエイリアスぶんの誤差を許容する。
        #expect(abs(CGFloat(minX) - localX) <= 2)
    }

    /// 白背景でない画素が最初に現れる列を返す。チャネル順に依存しないよう全バイトで判定する。
    private static func minColoredColumn(in image: CGImage) -> Int? {
        guard let data = image.dataProvider?.data as Data? else { return nil }
        let bytesPerRow = image.bytesPerRow
        let bytesPerPixel = image.bitsPerPixel / 8
        for col in 0..<image.width {
            for row in 0..<image.height {
                let offset = row * bytesPerRow + col * bytesPerPixel
                for byte in 0..<bytesPerPixel where data[offset + byte] < 235 {
                    return col
                }
            }
        }
        return nil
    }
}
