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
    let onSelect: (TimeLog) -> Void
    let onAddLog: (Project, Date, Date) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    var activeHighlightColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.yellow.opacity(0.18)
    }

    /// 1 時間あたりの幅（pt）。横ドラッグの分解能に直結する。
    let pointsPerHour: CGFloat = 48
    /// 日付ラベル用の左余白。
    let dayGutter: CGFloat = 96
    /// 1 レーン（1 行）の高さ。
    let laneHeight: CGFloat = 28
    /// レーン間の余白。
    let laneGap: CGFloat = 4
    /// 短い記録でも掴めるようにする最小ブロック幅。
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
    /// リサイズ時の最小計測時間。
    var minDuration: TimeInterval { TimeInterval(snapMinutes * 60) }

    /// 現在時刻マーカーの更新用（60 秒ごと）。
    @State var now = Date()

    // ドラッグ中のローカル状態（確定までモデルへ書き込まない）。
    @State private var dragLogID: UUID?
    @State private var dragMode: DragMode = .move
    @State private var dragOrigStart: Date = .distantPast
    @State private var dragOrigEnd: Date = .distantPast
    @State private var dragStart: Date = .distantPast
    @State private var dragEnd: Date = .distantPast
    /// 移動ドラッグ中の縦方向の日数ずれ（ライブプレビューの行オフセットに使う）。
    @State private var dragDayDelta: Int = 0
    /// ドラッグ中に tapSlop を超えたか（元の位置に戻してもタップ扱いしない）。
    @State private var dragDidMove: Bool = false

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
        .onReceive(nowTimer) { now = $0 }
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

    // MARK: - ブロック

    @ViewBuilder
    private func block(for item: LaidOut, day: Date) -> some View {
        let log = item.log
        let isDragging = dragLogID == log.id
        let start = isDragging ? dragStart : log.startDate
        let end = isDragging ? dragEnd : effectiveEnd(of: log)

        // ドラッグ中は移動後の開始時刻の「その日 0:00」を基準に列位置を出す（日付跨ぎ対応）。
        let anchorDay = isDragging ? dayStart(of: start) : day
        let offsetX = xPos(start, dayStart: anchorDay)
        let width = max(minBlockWidth, CGFloat(end.timeIntervalSince(start) / 3600) * pointsPerHour)
        // 縦は通常はレーン位置。移動ドラッグ中だけ移動先の行までライブで縦オフセットする。
        let baseOffsetY = CGFloat(item.lane) * laneHeight
        let offsetY = (isDragging && dragMode == .move) ? baseOffsetY + rowYDelta(for: day) : baseOffsetY

        let content = blockContent(log: log, start: start, end: end, width: width)
            .frame(width: width, height: laneHeight - laneGap, alignment: .leading)
            .overlay { if !log.isRunning { cursorZones(width: width) } }
            .contentShape(Rectangle())
            .offset(x: offsetX, y: offsetY)

        // 計測中は読み取り専用。それ以外は常に同じビュー階層を維持する
        // （ドラッグ中に分岐するとSwiftUIがジェスチャーをキャンセルする）。
        if log.isRunning {
            content
        } else {
            content
                .overlay(alignment: .topLeading) {
                    if isDragging {
                        let snapped = snappedDragTimes()
                        let snapAnchor = dayStart(of: snapped.start)
                        let snapX = xPos(snapped.start, dayStart: snapAnchor)
                        let snapEndX = xPos(snapped.end, dayStart: snapAnchor)
                        let snapWidth = max(minBlockWidth, snapEndX - snapX)
                        snapPreview(
                            snapX: snapX, snapWidth: snapWidth,
                            snappedStart: snapped.start, snappedEnd: snapped.end
                        )
                    }
                }
                .contextMenu {
                    Button("削除", role: .destructive) {
                        TimeLogEditing.delete(log, in: context)
                    }
                }
                .gesture(blockGesture(for: log, offsetX: offsetX, width: width))
        }
    }

    @ViewBuilder
    private func blockContent(log: TimeLog, start: Date, end: Date, width: CGFloat) -> some View {
        let strokeColor = log.isRunning ? Color.green : Color.white.opacity(0.4)
        let hasNotes = !log.notes.isEmpty
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 5)
                .fill((log.project?.color ?? .gray).opacity(log.isRunning ? 0.25 : 0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(strokeColor, lineWidth: log.isRunning ? 1.5 : 0.5)
                )

            if width > 36 {
                HStack(spacing: 3) {
                    Text(log.isRunning ? "計測中" : (log.project?.name ?? "（不明）"))
                        .font(.caption2.bold())
                        .lineLimit(1)
                        .foregroundStyle(log.isRunning ? Color.green : Color.white)
                    if hasNotes && !log.isRunning {
                        Image(systemName: "note.text")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 5)
            } else if hasNotes && !log.isRunning {
                Image(systemName: "note.text")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
            }
        }
        .help(blockHelp(log: log, start: start, end: end))
    }

    // MARK: - ドラッグ／タップ（統合ジェスチャー）

    /// ブロック 1 つに付ける唯一のジェスチャー。押下位置で移動／リサイズを判定し、
    /// 移動量がほぼゼロならタップ（編集シート）として扱う。
    private func blockGesture(for log: TimeLog, offsetX: CGFloat, width: CGFloat) -> some Gesture {
        // 座標空間をコンテンツ全体に固定。ブロック左端（dayGutter + offsetX）を引いてブロック内 X を得る。
        // .offset はレイアウト位置を変えないため、ローカル座標のままだと常に原点基準（≒ offsetX 込み）に
        // なり、全ドラッグが右端リサイズと誤判定されてしまう。Y は縦方向の日付行判定に使う。
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
                    onSelect(log)
                } else {
                    commitDrag(for: log)
                }
            }
    }

    /// マウス位置に応じてカーソルを切り替える透明ゾーン。
    /// 端＝左右リサイズ（<->）、中央＝指（リンク）カーソル。modeForStart の判定と一致させる。
    @ViewBuilder
    private func cursorZones(width: CGFloat) -> some View {
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

    /// 移動ドラッグ中の縦オフセット（元の行 → 移動先の行の上端 Y の差）。
    private func rowYDelta(for day: Date) -> CGFloat {
        guard dragDayDelta != 0 else { return 0 }
        let starts = rowYStarts
        guard let origIndex = dayRows.firstIndex(where: { $0.day == day }) else { return 0 }
        let target = min(max(0, origIndex + dragDayDelta), starts.count - 1)
        return starts[target] - starts[origIndex]
    }

}

// MARK: - ドラッグ操作

extension MonthTimelineView {
    fileprivate func modeForStart(startX: CGFloat, width: CGFloat) -> DragMode {
        guard width >= resizeEdgeMin else { return .move }
        if startX <= resizeEdgeWidth { return .resizeStart }
        if startX >= width - resizeEdgeWidth { return .resizeEnd }
        return .move
    }

    fileprivate func applyDrag(translationWidth: CGFloat, dayDelta: Int) {
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

    fileprivate func commitDrag(for log: TimeLog) {
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

    fileprivate func snapped(_ date: Date) -> Date {
        let interval = TimeInterval(snapMinutes * 60)
        let rounded = (date.timeIntervalSinceReferenceDate / interval).rounded() * interval
        return Date(timeIntervalSinceReferenceDate: rounded)
    }

    /// ドラッグ中のスナップ後の着地時刻を返す。
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
}
