import SwiftUI

// MARK: - ドラッグ操作

extension MonthTimelineView {
    func modeForStart(startX: CGFloat, width: CGFloat) -> DragMode {
        guard width >= resizeEdgeMin else { return .move }
        if startX <= resizeEdgeWidth { return .resizeStart }
        if startX >= width - resizeEdgeWidth { return .resizeEnd }
        return .move
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

    func xForHour(_ hour: Int) -> CGFloat {
        CGFloat(hour - rangeStartHour) * pointsPerHour
    }

    func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(Self.maxPointsPerHour, max(Self.minPointsPerHour, value))
    }
}
