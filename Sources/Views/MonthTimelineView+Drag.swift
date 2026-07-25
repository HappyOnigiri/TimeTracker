import SwiftUI

// MARK: - ドラッグ操作

extension MonthTimelineView {
    /// ブロック幅に応じた左右端の判定幅。
    /// 端の幅を固定にすると、狭いブロックでは左右の端が重なって判定が破綻するため、
    /// `edgeWidth * 3` 未満の幅では「開始端・中央・終了端」の 3 等分に縮める。
    static func resizeEdgeInset(blockWidth: CGFloat, edgeWidth: CGFloat) -> CGFloat {
        min(edgeWidth, max(0, blockWidth) / 3)
    }

    /// 押下位置（ブロック左端からの X）から移動／リサイズを決める。
    static func dragMode(startX: CGFloat, blockWidth: CGFloat, edgeWidth: CGFloat) -> DragMode {
        let edge = resizeEdgeInset(blockWidth: blockWidth, edgeWidth: edgeWidth)
        guard edge > 0 else { return .move }
        if startX <= edge { return .resizeStart }
        if startX >= blockWidth - edge { return .resizeEnd }
        return .move
    }

    func modeForStart(startX: CGFloat, width: CGFloat) -> DragMode {
        Self.dragMode(startX: startX, blockWidth: width, edgeWidth: resizeEdgeWidth)
    }

    func applyDrag(translationWidth: CGFloat, dayDelta: Int) {
        let deltaSeconds = Double(translationWidth / pointsPerHour) * 3600
        switch dragMode {
        case .move:
            let cal = Calendar.current
            let shiftedStart = cal.date(byAdding: .day, value: dayDelta, to: dragOrigStart) ?? dragOrigStart
            let duration = dragOrigEnd.timeIntervalSince(dragOrigStart)
            dragStart = shiftedStart.addingTimeInterval(deltaSeconds)
            dragEnd = dragStart.addingTimeInterval(duration)
        case .resizeStart:
            let proposed = dragOrigStart.addingTimeInterval(deltaSeconds)
            dragStart = min(proposed, dragOrigEnd.addingTimeInterval(-minDuration))
            dragEnd = dragOrigEnd
        case .resizeEnd:
            let proposed = dragOrigEnd.addingTimeInterval(deltaSeconds)
            dragEnd = max(proposed, dragOrigStart.addingTimeInterval(minDuration))
            dragStart = dragOrigStart
        }
    }

    func commitDrag(for log: TimeLog) {
        defer { dragLogID = nil }
        guard dragLogID == log.id else { return }

        var start = dragStart
        var end = dragEnd
        switch dragMode {
        case .move:
            let duration = end.timeIntervalSince(start)
            start = snapped(start)
            end = start.addingTimeInterval(duration)
        case .resizeStart:
            start = snapped(start)
            if end.timeIntervalSince(start) < minDuration {
                start = end.addingTimeInterval(-minDuration)
            }
        case .resizeEnd:
            end = snapped(end)
            if end.timeIntervalSince(start) < minDuration {
                end = start.addingTimeInterval(minDuration)
            }
        }
        TimeLogEditing.updateTimes(log, start: start, end: end, in: context)
    }

    func snapped(_ date: Date) -> Date {
        let interval = TimeInterval(snapMinutes * 60)
        let rounded = (date.timeIntervalSinceReferenceDate / interval).rounded() * interval
        return Date(timeIntervalSinceReferenceDate: rounded)
    }

    func snappedDragTimes() -> (start: Date, end: Date) {
        var start = dragStart
        var end = dragEnd
        switch dragMode {
        case .move:
            let duration = end.timeIntervalSince(start)
            start = snapped(start)
            end = start.addingTimeInterval(duration)
        case .resizeStart:
            start = snapped(start)
            if end.timeIntervalSince(start) < minDuration {
                start = end.addingTimeInterval(-minDuration)
            }
        case .resizeEnd:
            end = snapped(end)
            if end.timeIntervalSince(start) < minDuration {
                end = start.addingTimeInterval(minDuration)
            }
        }
        return (start, end)
    }

}
