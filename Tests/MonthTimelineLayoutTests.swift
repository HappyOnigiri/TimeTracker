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

    // MARK: - ドラッグ判定（移動／リサイズ）

    private let edgeWidth: CGFloat = 8

    @Test("幅24pt以上のブロックでは端の判定幅が固定値のまま")
    func edgeInsetStaysFixedOnWideBlocks() {
        #expect(MonthTimelineView.resizeEdgeInset(blockWidth: 24, edgeWidth: edgeWidth) == 8)
        #expect(MonthTimelineView.resizeEdgeInset(blockWidth: 48, edgeWidth: edgeWidth) == 8)
    }

    @Test("幅24pt未満のブロックでは端の判定幅を3等分まで縮める")
    func edgeInsetShrinksOnNarrowBlocks() {
        #expect(MonthTimelineView.resizeEdgeInset(blockWidth: 18, edgeWidth: edgeWidth) == 6)
        #expect(abs(MonthTimelineView.resizeEdgeInset(blockWidth: 12, edgeWidth: edgeWidth) - 4) < accuracy)
        #expect(MonthTimelineView.resizeEdgeInset(blockWidth: 0, edgeWidth: edgeWidth) == 0)
        #expect(MonthTimelineView.resizeEdgeInset(blockWidth: -5, edgeWidth: edgeWidth) == 0)
    }

    @Test("幅48ptのブロックは端でリサイズ・中央で移動になる")
    func wideBlockDragModes() {
        #expect(MonthTimelineView.dragMode(startX: 0, blockWidth: 48, edgeWidth: edgeWidth) == .resizeStart)
        #expect(MonthTimelineView.dragMode(startX: 8, blockWidth: 48, edgeWidth: edgeWidth) == .resizeStart)
        #expect(MonthTimelineView.dragMode(startX: 24, blockWidth: 48, edgeWidth: edgeWidth) == .move)
        #expect(MonthTimelineView.dragMode(startX: 40, blockWidth: 48, edgeWidth: edgeWidth) == .resizeEnd)
        #expect(MonthTimelineView.dragMode(startX: 48, blockWidth: 48, edgeWidth: edgeWidth) == .resizeEnd)
    }

    @Test("48pt/hourの30分ブロック（幅24pt）でも端でリサイズできる")
    func thirtyMinuteBlockIsResizable() {
        let width: CGFloat = 24
        #expect(MonthTimelineView.dragMode(startX: 2, blockWidth: width, edgeWidth: edgeWidth) == .resizeStart)
        #expect(MonthTimelineView.dragMode(startX: 12, blockWidth: width, edgeWidth: edgeWidth) == .move)
        #expect(MonthTimelineView.dragMode(startX: 22, blockWidth: width, edgeWidth: edgeWidth) == .resizeEnd)
    }

    @Test("最小幅（18pt）まで縮んだブロックでも3モードすべてを判定できる")
    func minimumWidthBlockKeepsAllModes() {
        let width: CGFloat = 18
        #expect(MonthTimelineView.dragMode(startX: 1, blockWidth: width, edgeWidth: edgeWidth) == .resizeStart)
        #expect(MonthTimelineView.dragMode(startX: 6, blockWidth: width, edgeWidth: edgeWidth) == .resizeStart)
        #expect(MonthTimelineView.dragMode(startX: 9, blockWidth: width, edgeWidth: edgeWidth) == .move)
        #expect(MonthTimelineView.dragMode(startX: 12, blockWidth: width, edgeWidth: edgeWidth) == .resizeEnd)
        #expect(MonthTimelineView.dragMode(startX: 17, blockWidth: width, edgeWidth: edgeWidth) == .resizeEnd)
    }

    @Test("ブロック外側の押下位置は近い側の端に丸められる")
    func outOfBoundsStartClampsToNearestEdge() {
        #expect(MonthTimelineView.dragMode(startX: -3, blockWidth: 18, edgeWidth: edgeWidth) == .resizeStart)
        #expect(MonthTimelineView.dragMode(startX: 21, blockWidth: 18, edgeWidth: edgeWidth) == .resizeEnd)
    }

    @Test("幅0のブロックは移動のみ")
    func zeroWidthBlockFallsBackToMove() {
        #expect(MonthTimelineView.dragMode(startX: 0, blockWidth: 0, edgeWidth: edgeWidth) == .move)
    }
}
