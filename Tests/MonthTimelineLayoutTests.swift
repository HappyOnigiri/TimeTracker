import CoreGraphics
import Testing
@testable import TimeTracker

@MainActor
struct MonthTimelineLayoutTests {
    private let accuracy: CGFloat = 0.0001

    @Test("左方向スナップで点線の合成座標がスナップ位置と一致する")
    func leftwardSnap() {
        let blockX: CGFloat = 6.4
        let startX: CGFloat = 6
        let endX: CGFloat = 12
        let preview = MonthTimelineView.snapPreviewGeometry(
            blockX: blockX,
            startX: startX,
            endX: endX
        )

        #expect(abs(preview.localX - (-0.4)) < accuracy)
        #expect(preview.width == 6)
        #expect(abs(blockX + preview.localX - startX) < accuracy)
        #expect(abs(blockX + preview.localX + preview.width - endX) < accuracy)
    }

    @Test("14pt/hourの30分記録では点線幅が通常ブロックの最小幅を下回る")
    func thirtyMinutesAtFourteenPointsPerHour() {
        let blockX: CGFloat = 70
        let startX: CGFloat = 70
        let endX: CGFloat = 77
        let preview = MonthTimelineView.snapPreviewGeometry(
            blockX: blockX,
            startX: startX,
            endX: endX
        )

        #expect(preview.localX == 0)
        #expect(preview.width == 7)
        #expect(preview.width < 14)
    }

    @Test("右方向スナップで点線の合成座標がスナップ位置と一致する")
    func rightwardSnap() {
        let blockX: CGFloat = 5.6
        let startX: CGFloat = 6
        let endX: CGFloat = 12
        let preview = MonthTimelineView.snapPreviewGeometry(
            blockX: blockX,
            startX: startX,
            endX: endX
        )

        #expect(abs(preview.localX - 0.4) < accuracy)
        #expect(abs(blockX + preview.localX - startX) < accuracy)
        #expect(abs(blockX + preview.localX + preview.width - endX) < accuracy)
    }

    @Test("最小幅を超える記録でも点線の合成座標がスナップ位置と一致する")
    func recordWiderThanMinimumWidth() {
        let blockX: CGFloat = 24.4
        let startX: CGFloat = 24
        let endX: CGFloat = 48
        let preview = MonthTimelineView.snapPreviewGeometry(
            blockX: blockX,
            startX: startX,
            endX: endX
        )

        #expect(preview.width == 24)
        #expect(abs(blockX + preview.localX - startX) < accuracy)
        #expect(abs(blockX + preview.localX + preview.width - endX) < accuracy)
    }

    @Test("終了位置が開始位置より前なら点線幅を0にする")
    func clampsReversedCoordinates() {
        let preview = MonthTimelineView.snapPreviewGeometry(
            blockX: 132,
            startX: 132,
            endX: 120
        )

        #expect(preview.localX == 0)
        #expect(preview.width == 0)
    }
}
