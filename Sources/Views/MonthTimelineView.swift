import AppKit
import SwiftData
import SwiftUI

/// 1 か月分の記録を「行＝日付・横軸＝時刻」のタイムラインで表示し、
/// ブロックの横ドラッグで移動・左右端でリサイズして編集する画面。
/// 横軸は稼働の有無に関わらず 0〜24 時で固定、行は当月の全日を表示する。
/// 同じ日に時間が重なる記録は複数レーン（行）に分けて表示する。
/// - ブロック中央の横ドラッグ: 開始・終了を一緒に移動。
/// - ブロック左右端（端 8pt）の横ドラッグ: 開始/終了のみリサイズ。
/// - タップ（移動量ほぼゼロ）: 編集シートを開く。
/// - 計測中（`endDate == nil`）のログは読み取り専用（移動・リサイズ・タップすべて無効）。
struct MonthTimelineView: View {
    /// 表示対象の月（その月の 1 日 0:00）。当月の全日を行として描画するために使う。
    let month: Date
    let logs: [TimeLog]
    let projects: [Project]
    let activeSessions: [ActiveSession]
    @Binding var popoverLog: TimeLog?
    let onAddLog: (Project, Date, Date) -> Void

    init(
        month: Date, logs: [TimeLog], projects: [Project],
        activeSessions: [ActiveSession],
        pointsPerHour: Binding<CGFloat>,
        popoverLog: Binding<TimeLog?>,
        onAddLog: @escaping (Project, Date, Date) -> Void
    ) {
        self.month = month
        self.logs = logs
        self.projects = projects
        self.activeSessions = activeSessions
        self._pointsPerHour = pointsPerHour
        self._popoverLog = popoverLog
        self.onAddLog = onAddLog
    }

    @Environment(\.modelContext) var context
    @Environment(\.colorScheme) var colorScheme

    var activeHighlightColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.yellow.opacity(0.18)
    }

    /// 1 時間あたりの幅（pt）。横ドラッグの分解能に直結する。
    @Binding var pointsPerHour: CGFloat
    @State private var zoomAnchor: CGFloat = 48
    @State private var isPinching: Bool = false
    @State private var scrollWheelMonitor: Any?

    static let minPointsPerHour: CGFloat = 12
    static let maxPointsPerHour: CGFloat = 480

    static func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(maxPointsPerHour, max(minPointsPerHour, value))
    }

    /// 日付ラベル用の左余白。
    let dayGutter: CGFloat = 96
    /// 1 レーン（1 行）の高さ。
    let laneHeight: CGFloat = 28
    /// レーン間の余白。
    let laneGap: CGFloat = 4
    /// 通常ブロックの視認性とヒット領域を確保する最小幅。実時刻を示す点線プレビューには適用しない。
    let minBlockWidth: CGFloat = 14
    /// 左右端のリサイズ判定に使う幅（pt）。
    let resizeEdgeWidth: CGFloat = 8
    /// リサイズ判定を有効にする最小ブロック幅（これ未満は移動のみ）。
    let resizeEdgeMin: CGFloat = 28
    /// タップ（編集）とみなす最大移動量（pt）。
    let tapSlop: CGFloat = 4
    /// 確定時のスナップ単位（分）。
    @AppStorage(AppSettingsKey.timelineSnapMinutes)
    var snapMinutes: Int = AppSettingsDefault.timelineSnapMinutes
    @AppStorage(AppSettingsKey.dimBlocksWithoutNotes)
    var dimBlocksWithoutNotes: Bool = AppSettingsDefault.dimBlocksWithoutNotes
    /// リサイズ時の最小計測時間。
    var minDuration: TimeInterval { TimeInterval(snapMinutes * 60) }

    /// 現在時刻マーカーの更新用（60 秒ごと）。
    @State var now = Date()

    @State var dragLogID: UUID?
    @State var dragMode: DragMode = .move
    @State var dragOrigStart: Date = .distantPast
    @State var dragOrigEnd: Date = .distantPast
    @State var dragStart: Date = .distantPast
    @State var dragEnd: Date = .distantPast
    @State var dragDayDelta: Int = 0
    @State var dragDidMove: Bool = false

    enum DragMode {
        case move, resizeStart, resizeEnd
    }

    /// ブロック内クリック位置・縦方向の日付行判定に使う、コンテンツ全体の名前付き座標空間。
    static let contentSpace = "MonthTimelineContent"
    /// ヘッダ（時刻目盛り）の高さ。縦方向の行 Y 算出に使う。
    let headerHeight: CGFloat = 14
    /// VStack の行間。縦方向の行 Y 算出に使う（body の spacing と一致させる）。
    let rowSpacing: CGFloat = 10
    /// コンテンツ外周の余白。座標空間は padding を含むため、ブロック内 X 算出時に差し引く。
    let contentPadding: CGFloat = 12

    private let nowTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: rowSpacing, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(dayRows, id: \.day) { row in
                        dayRow(row)
                    }
                } header: {
                    header
                }
            }
            .padding(contentPadding)
            .coordinateSpace(name: MonthTimelineView.contentSpace)
        }
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    guard dragLogID == nil else { return }
                    isPinching = true
                    pointsPerHour = Self.clampedZoom(zoomAnchor * value.magnification)
                }
                .onEnded { value in
                    guard dragLogID == nil else { return }
                    pointsPerHour = Self.clampedZoom(zoomAnchor * value.magnification)
                    zoomAnchor = pointsPerHour
                    isPinching = false
                }
        )
        .onAppear {
            if let old = scrollWheelMonitor { NSEvent.removeMonitor(old) }
            scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                guard event.modifierFlags.contains(.command) else { return event }
                guard !isPinching, dragLogID == nil else { return event }
                guard event.window == NSApp.keyWindow else { return event }
                let sensitivity: CGFloat = event.hasPreciseScrollingDeltas ? 0.005 : 0.05
                let delta = event.scrollingDeltaY * sensitivity
                pointsPerHour = Self.clampedZoom(pointsPerHour * (1 + delta))
                zoomAnchor = pointsPerHour
                return nil
            }
        }
        .onDisappear {
            if let monitor = scrollWheelMonitor {
                NSEvent.removeMonitor(monitor)
                scrollWheelMonitor = nil
            }
        }
        .onReceive(nowTimer) { now = $0 }
        .onChange(of: pointsPerHour) { _, newValue in
            if !isPinching { zoomAnchor = newValue }
        }
    }

    // MARK: - ヘッダ（時刻目盛り）

    private var header: some View {
        let isCurrentMonth = Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
        return ZStack(alignment: .topLeading) {
            ForEach(rangeStartHour...rangeEndHour, id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .offset(x: dayGutter + xForHour(hour) - 6)
            }
            if isCurrentMonth {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 1.5, height: 14)
                    .offset(x: dayGutter + xPos(now, dayStart: dayStart(of: now)) - 0.25)
            }
        }
        .frame(width: dayGutter + trackWidth, height: 14, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 1 日分の行

    private func dayRow(_ row: DayRow) -> some View {
        let rowHeight = CGFloat(row.laneCount) * laneHeight
        // ドラッグ中のブロックを含む行は、はみ出しても他行の上に描くため最前面へ。
        let isDraggingRow = row.items.contains { $0.log.id == dragLogID }
        let isToday = Calendar.current.isDateInToday(row.day)
        return HStack(alignment: .top, spacing: 0) {
            Text(MonthTimelineView.dayLabel(for: row.day))
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .frame(width: dayGutter, height: laneHeight, alignment: .leading)

            ZStack(alignment: .topLeading) {
                activeBackground(for: row.day, height: rowHeight)
                gridlines(height: rowHeight)
                hourSegments(row: row, rowHeight: rowHeight)
                ForEach(row.items, id: \.log.id) { item in
                    block(for: item, day: row.day)
                }
                if isToday {
                    nowMarker(height: rowHeight)
                }
            }
            .frame(width: trackWidth, height: rowHeight, alignment: .topLeading)
        }
        .zIndex(isDraggingRow ? 1 : 0)
    }

    private func gridlines(height: CGFloat) -> some View {
        ForEach(rangeStartHour...rangeEndHour, id: \.self) { hour in
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 1, height: height)
                .offset(x: xForHour(hour))
        }
    }

}

// MARK: - ブロック描画

extension MonthTimelineView {
    @ViewBuilder
    func block(for item: LaidOut, day: Date) -> some View {
        let log = item.log
        let isDragging = dragLogID == log.id
        let start = isDragging ? dragStart : log.startDate
        let end = isDragging ? dragEnd : effectiveEnd(of: log)

        let anchorDay = isDragging ? dayStart(of: start) : day
        let offsetX = xPos(start, dayStart: anchorDay)
        let width = max(minBlockWidth, CGFloat(end.timeIntervalSince(start) / 3600) * pointsPerHour)
        let baseOffsetY = CGFloat(item.lane) * laneHeight
        let offsetY = (isDragging && dragMode == .move) ? baseOffsetY + rowYDelta(for: day) : baseOffsetY

        let content = blockContent(log: log, start: start, end: end, width: width)
            .frame(width: width, height: laneHeight - laneGap, alignment: .leading)
            .overlay { if !log.isRunning { cursorZones(width: width) } }
            .contentShape(Rectangle())

        if log.isRunning {
            content
                .offset(x: offsetX, y: offsetY)
        } else {
            content
                .overlay(alignment: .topLeading) {
                    dragSnapOverlay(isDragging: isDragging, blockX: offsetX)
                }
                .offset(x: offsetX, y: offsetY)
                .blockPopover(
                    isPresented: Binding(
                        get: { popoverLog?.id == log.id },
                        set: { if !$0 { popoverLog = nil } }
                    ),
                    log: log, projects: projects,
                    onSave: { proj, newStart, newEnd, newNotes in
                        TimeLogEditing.update(
                            log, project: proj, start: newStart,
                            end: newEnd, notes: newNotes, in: context
                        )
                    },
                    onDelete: { TimeLogEditing.delete($0, in: context) }
                )
                .contextMenu {
                    Button("削除", role: .destructive) {
                        TimeLogEditing.delete(log, in: context)
                    }
                }
                .gesture(blockGesture(for: log, offsetX: offsetX, width: width))
        }
    }

    @ViewBuilder
    func dragSnapOverlay(isDragging: Bool, blockX: CGFloat) -> some View {
        if isDragging {
            let snapped = snappedDragTimes()
            let snapAnchor = dayStart(of: snapped.start)
            let snapX = xPos(snapped.start, dayStart: snapAnchor)
            let snapEndX = xPos(snapped.end, dayStart: snapAnchor)
            let preview = Self.snapPreviewGeometry(
                blockX: blockX, startX: snapX, endX: snapEndX
            )
            snapPreview(
                localX: preview.localX, width: preview.width,
                snappedStart: snapped.start, snappedEnd: snapped.end
            )
        }
    }

    @ViewBuilder
    func blockContent(log: TimeLog, start: Date, end: Date, width: CGFloat) -> some View {
        let hasNotes = !log.notes.isEmpty
        let dim = dimBlocksWithoutNotes && !hasNotes && !log.isRunning
        let strokeColor: Color = log.isRunning ? .green
            : dim ? .orange
            : hasNotes ? .white.opacity(0.7) : .white.opacity(0.4)
        let strokeWidth: CGFloat = log.isRunning ? 1.5 : dim ? 1.0 : hasNotes ? 1.0 : 0.5
        let fillOpacity: Double = log.isRunning ? 0.25 : dim ? 0.5 : 0.85
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 5)
                .fill((log.project?.color ?? .gray).opacity(fillOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )

            if dim {
                HatchPattern()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 0.5)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            if width > 36 {
                Text(log.isRunning ? "計測中" : (log.project?.name ?? "（不明）"))
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .foregroundStyle(log.isRunning ? Color.green : Color.white)
                    .padding(.horizontal, 5)
            }
        }
        .help(blockHelp(log: log, start: start, end: end))
    }
}

// MARK: - ドラッグ／タップ（統合ジェスチャー）

extension MonthTimelineView {
    /// ブロック 1 つに付ける唯一のジェスチャー。押下位置で移動／リサイズを判定し、
    /// 移動量がほぼゼロならタップ（編集シート）として扱う。
    func blockGesture(for log: TimeLog, offsetX: CGFloat, width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(MonthTimelineView.contentSpace))
            .onChanged { value in
                if dragLogID != log.id {
                    dragLogID = log.id
                    let blockX = value.startLocation.x - contentPadding - dayGutter - offsetX
                    dragMode = modeForStart(startX: blockX, width: width)
                    dragOrigStart = log.startDate
                    dragOrigEnd = effectiveEnd(of: log)
                    dragStart = dragOrigStart
                    dragEnd = dragOrigEnd
                    dragDayDelta = 0
                    dragDidMove = false
                }
                let moved = abs(value.translation.width) + abs(value.translation.height)
                if !dragDidMove && moved >= tapSlop {
                    dragDidMove = true
                }
                dragDayDelta = dragMode == .move
                    ? rowIndex(atY: value.location.y) - rowIndex(atY: value.startLocation.y)
                    : 0
                applyDrag(translationWidth: value.translation.width, dayDelta: dragDayDelta)
            }
            .onEnded { _ in
                if !dragDidMove {
                    dragLogID = nil
                    popoverLog = log
                } else {
                    commitDrag(for: log)
                }
            }
    }

    @ViewBuilder
    func cursorZones(width: CGFloat) -> some View {
        if width >= resizeEdgeMin {
            HStack(spacing: 0) {
                Color.clear.frame(width: resizeEdgeWidth).pointerCursor(.resizeLeftRight)
                Color.clear.pointerCursor(.pointingHand)
                Color.clear.frame(width: resizeEdgeWidth).pointerCursor(.resizeLeftRight)
            }
        } else {
            Color.clear.pointerCursor(.pointingHand)
        }
    }

    func rowYDelta(for day: Date) -> CGFloat {
        guard dragDayDelta != 0 else { return 0 }
        let starts = rowYStarts
        guard let origIndex = dayRows.firstIndex(where: { $0.day == day }) else { return 0 }
        let target = min(max(0, origIndex + dragDayDelta), starts.count - 1)
        return starts[target] - starts[origIndex]
    }
}
