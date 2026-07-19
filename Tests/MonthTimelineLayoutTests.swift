import CoreGraphics
import Testing
@testable import TimeTracker

@MainActor
struct MonthTimelineLayoutTests {
    @Test("最低ズームで30分記録の点線幅が実時間と一致する")
    func minimumZoomThirtyMinutes() {
        let startX: CGFloat = 120
        let endX: CGFloat = 126
        let width = MonthTimelineView.snapPreviewWidth(startX: startX, endX: endX)

        #expect(width == 6)
        #expect(startX + width == endX)
    }

    @Test("最低ズームで60分記録の点線幅が実時間と一致する")
    func minimumZoomSixtyMinutes() {
        let width = MonthTimelineView.snapPreviewWidth(startX: 120, endX: 132)

        #expect(width == 12)
    }

    @Test("低ズームで短時間記録の点線右端が終了位置と一致する")
    func lowZoomShortRecords() {
        let startX: CGFloat = 120

        for endX: CGFloat in [128, 132] {
            let width = MonthTimelineView.snapPreviewWidth(startX: startX, endX: endX)
            #expect(startX + width == endX)
        }
    }

    @Test("最低ズームで2時間記録の点線幅が実時間と一致する")
    func minimumZoomTwoHours() {
        let width = MonthTimelineView.snapPreviewWidth(startX: 120, endX: 144)

        #expect(width == 24)
    }

    @Test("終了位置が開始位置より前なら点線幅を0にする")
    func clampsReversedCoordinates() {
        let width = MonthTimelineView.snapPreviewWidth(startX: 132, endX: 120)

        #expect(width == 0)
    }
}
