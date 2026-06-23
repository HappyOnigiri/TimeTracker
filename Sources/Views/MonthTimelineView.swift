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
    let onSelect: (TimeLog) -> Void

    @Environment(\.modelContext) private var context

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
    let snapMinutes: Int = 5
    /// リサイズ時の最小計測時間。
    let minDuration: TimeInterval = 300

    // ドラッグ中のローカル状態（確定までモデルへ書き込まない）。
    @State private var dragLogID: UUID?
    @State private var dragMode: DragMode = .move
    @State private var dragOrigStart: Date = .distantPast
    @State private var dragOrigEnd: Date = .distantPast
    @State private var dragStart: Date = .distantPast
    @State private var dragEnd: Date = .distantPast
    /// 移動ドラッグ中の縦方向の日数ずれ（ライブプレビューの行オフセットに使う）。
    @State private var dragDayDelta: Int = 0

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
    }

    // MARK: - ヘッダ（時刻目盛り）

    private var header: some View {
        ZStack(alignment: .topLeading) {
            ForEach(rangeStartHour...rangeEndHour, id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .offset(x: dayGutter + xForHour(hour) - 6)
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
        return HStack(alignment: .top, spacing: 0) {
            Text(MonthTimelineView.dayLabel(for: row.day))
                .font(.callout)
                .frame(width: dayGutter, height: laneHeight, alignment: .leading)

            ZStack(alignment: .topLeading) {
                gridlines(height: rowHeight)
                ForEach(row.items, id: \.log.id) { item in
                    block(for: item, day: row.day)
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

        // 計測中は読み取り専用（タップ・移動・リサイズすべて無効）。
        // それ以外は 1 ブロック 1 ジェスチャーに統合し、macOS のジェスチャー調停の
        // デッドロックを避ける（押下位置で移動／リサイズを判定、移動量ゼロはタップ）。
        if log.isRunning {
            content
        } else {
            content.gesture(blockGesture(for: log, offsetX: offsetX, width: width))
        }
    }

    @ViewBuilder
    private func blockContent(log: TimeLog, start: Date, end: Date, width: CGFloat) -> some View {
        let strokeColor = log.isRunning ? Color.green : Color.white.opacity(0.4)
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 5)
                .fill((log.project?.color ?? .gray).opacity(log.isRunning ? 0.25 : 0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(strokeColor, lineWidth: log.isRunning ? 1.5 : 0.5)
                )

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
                }
                // 移動時のみ、押下行から現在行への差で日数をずらす（縦ドラッグ＝日付跨ぎ）。
                dragDayDelta = dragMode == .move
                    ? rowIndex(atY: value.location.y) - rowIndex(atY: value.startLocation.y)
                    : 0
                applyDrag(translationWidth: value.translation.width, dayDelta: dragDayDelta)
            }
            .onEnded { value in
                let moved = abs(value.translation.width) + abs(value.translation.height)
                if moved < tapSlop {
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

    /// 押下位置（ブロック内 X 座標）から操作モードを決める。
    private func modeForStart(startX: CGFloat, width: CGFloat) -> DragMode {
        guard width >= resizeEdgeMin else { return .move }
        if startX <= resizeEdgeWidth { return .resizeStart }
        if startX >= width - resizeEdgeWidth { return .resizeEnd }
        return .move
    }

    /// ドラッグ中の開始・終了をローカル状態へ反映する（確定までモデルへ書かない）。
    private func applyDrag(translationWidth: CGFloat, dayDelta: Int) {
        let deltaSeconds = Double(translationWidth / pointsPerHour) * 3600
        switch dragMode {
        case .move:
            // 縦は日数（DST を考慮し Calendar で加算）、横は時刻。所要時間は保つ。
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

    /// ドラッグ確定。スナップして開始 < 終了を保証し、モデルへ反映する。
    private func commitDrag(for log: TimeLog) {
        defer { dragLogID = nil }
        guard dragLogID == log.id else { return }

        var start = dragStart
        var end = dragEnd
        switch dragMode {
        case .move:
            // 移動は所要時間を保ったまま開始をスナップする。
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

    /// 指定時刻を snapMinutes 単位に丸める。
    private func snapped(_ date: Date) -> Date {
        let interval = TimeInterval(snapMinutes * 60)
        let rounded = (date.timeIntervalSinceReferenceDate / interval).rounded() * interval
        return Date(timeIntervalSinceReferenceDate: rounded)
    }

    /// 時刻 → ヘッダ起点からの X 座標。
    private func xForHour(_ hour: Int) -> CGFloat {
        CGFloat(hour - rangeStartHour) * pointsPerHour
    }
}

// MARK: - 座標変換・表示範囲

extension MonthTimelineView {
    /// 計測中ログは「現在時刻（その日を超えない範囲）」を終了として扱う。
    func effectiveEnd(of log: TimeLog) -> Date {
        if let end = log.endDate { return end }
        let dayEnd = dayStart(of: log.startDate).addingTimeInterval(24 * 3600)
        return min(Date(), dayEnd)
    }

    func dayStart(of date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// dayStart からの経過時間（時）。負やはみ出しは clamp。
    func hourOffset(of date: Date, dayStart: Date) -> Double {
        let hours = date.timeIntervalSince(dayStart) / 3600
        return min(24, max(0, hours))
    }

    /// 時刻 → 当日トラック内の X 座標。
    func xPos(_ date: Date, dayStart: Date) -> CGFloat {
        CGFloat(hourOffset(of: date, dayStart: dayStart) - Double(rangeStartHour)) * pointsPerHour
    }

    /// 横軸の表示開始時（固定 0 時）。
    var rangeStartHour: Int { 0 }

    /// 横軸の表示終了時（固定 24 時 = 23:59 まで）。
    var rangeEndHour: Int { 24 }

    var trackWidth: CGFloat {
        CGFloat(rangeEndHour - rangeStartHour) * pointsPerHour
    }

    func blockHelp(log: TimeLog, start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        let name = log.project?.name ?? "（不明）"
        if log.isRunning {
            return "\(name)  \(formatter.string(from: start)) 〜 計測中"
        }
        let duration = DurationFormatter.string(from: end.timeIntervalSince(start))
        return "\(name)  \(formatter.string(from: start)) 〜 \(formatter.string(from: end))  (\(duration))"
    }

    /// 「6月1日(月)」の日本式日付ラベル。
    static func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }
}
