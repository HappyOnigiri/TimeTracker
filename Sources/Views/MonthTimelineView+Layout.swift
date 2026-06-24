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
    // MARK: - アクティブ時間背景

    func activeBackground(for day: Date, height: CGFloat) -> some View {
        let dayBegin = dayStart(of: day)
        let dayEnd = dayBegin.addingTimeInterval(24 * 3600)
        let sessions = activeSessions.filter { session in
            let end = session.endDate ?? Date()
            return session.startDate < dayEnd && end > dayBegin
        }
        return ForEach(sessions, id: \.id) { session in
            let clippedStart = max(session.startDate, dayBegin)
            let clippedEnd = min(session.endDate ?? Date(), dayEnd)
            let posX = xPos(clippedStart, dayStart: dayBegin)
            let width = CGFloat(clippedEnd.timeIntervalSince(clippedStart) / 3600) * pointsPerHour
            RoundedRectangle(cornerRadius: 3)
                .fill(activeHighlightColor)
                .frame(width: max(0, width), height: height)
                .offset(x: posX)
                .allowsHitTesting(false)
        }
    }

    // MARK: - ヘルパー

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

    static func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
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
