import AppKit
import SwiftData
import SwiftUI

// MARK: - 重なりレイアウト（日ごと・貪欲レーン割り当て）

extension MonthTimelineView {
    struct LaidOut {
        let log: TimeLog
        let lane: Int
    }

    struct DayRow {
        let day: Date
        let items: [LaidOut]
        let laneCount: Int
    }

    /// 当月の全日（1 日〜末日）を 0:00 の Date で昇順に並べたもの。
    var monthDays: [Date] {
        let calendar = Calendar.current
        let start = dayStart(of: month)
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    /// 当月の全日を行として返す。稼働がない日も空行として表示する（各日内は重なりをレーン割り当て）。
    var dayRows: [DayRow] {
        let grouped = Dictionary(grouping: logs) { dayStart(of: $0.startDate) }
        return monthDays.map { day in
            laidOut(day: day, logs: grouped[day] ?? [])
        }
    }

    /// 各日付行の上端 Y（コンテンツ座標空間）。ヘッダ＋行間＋各行高さから解析的に算出する。
    var rowYStarts: [CGFloat] {
        var result: [CGFloat] = []
        var top = headerHeight + rowSpacing
        for row in dayRows {
            result.append(top)
            top += CGFloat(row.laneCount) * laneHeight + rowSpacing
        }
        return result
    }

    /// 指定 Y がどの日付行に属するか（上下端はクランプ）。差分用なので共通オフセット誤差は相殺される。
    func rowIndex(atY posY: CGFloat) -> Int {
        let starts = rowYStarts
        guard !starts.isEmpty else { return 0 }
        var idx = 0
        for (index, start) in starts.enumerated() where posY >= start { idx = index }
        return idx
    }

    /// 1 日分の記録を、空いている最初のレーンへ貪欲に割り当てる。
    private func laidOut(day: Date, logs dayLogs: [TimeLog]) -> DayRow {
        let sorted = dayLogs.sorted { $0.startDate < $1.startDate }
        var laneEnds: [Date] = []
        var items: [LaidOut] = []
        for log in sorted {
            if let lane = laneEnds.firstIndex(where: { $0 <= log.startDate }) {
                laneEnds[lane] = effectiveEnd(of: log)
                items.append(LaidOut(log: log, lane: lane))
            } else {
                laneEnds.append(effectiveEnd(of: log))
                items.append(LaidOut(log: log, lane: laneEnds.count - 1))
            }
        }
        return DayRow(day: day, items: items, laneCount: max(1, laneEnds.count))
    }

    // MARK: - 空欄の右クリックメニュー（1 時間ごとのセグメント）

    @ViewBuilder
    func hourSegments(row: DayRow, rowHeight: CGFloat) -> some View {
        ForEach(rangeStartHour..<rangeEndHour, id: \.self) { hour in
            Color.clear
                .frame(width: pointsPerHour, height: rowHeight)
                .contentShape(Rectangle())
                .contextMenu {
                    Section("追加") {
                        ForEach(projects) { project in
                            Button {
                                let cal = Calendar.current
                                let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: row.day)!
                                let end = start.addingTimeInterval(3600)
                                onAddLog(project, start, end)
                            } label: {
                                Label(project.name, systemImage: "circle.fill")
                                    .foregroundStyle(project.color)
                            }
                        }
                    }
                }
                .offset(x: xForHour(hour))
        }
    }
    // MARK: - 現在時刻マーカー

    func nowMarker(height: CGFloat) -> some View {
        let markerX = xPos(now, dayStart: dayStart(of: now))
        return Rectangle()
            .fill(Color.red)
            .frame(width: 1.5, height: height)
            .offset(x: markerX - 0.25)
            .allowsHitTesting(false)
    }
}

// MARK: - カーソル

extension View {
    /// ホバー中だけ指定の NSCursor を表示する（離脱時に元へ戻す）。
    func pointerCursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
