import Charts
import SwiftData
import SwiftUI

/// 稼働時間レポートのダッシュボード。合計と日次推移をグラフ表示し、CSV 出力も行う。
struct DashboardView: View {
    @Query private var logs: [TimeLog]
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    /// 表示対象の月（その月の 1 日 0:00）。
    @State private var selectedMonth: Date = DashboardView.currentMonthStart
    /// 絞り込み対象のプロジェクト ID。nil のときはすべて表示。
    @State private var selectedProjectID: UUID?
    @State private var exportMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                controls
                if filteredLogs.isEmpty {
                    ContentUnavailableView("データがありません", systemImage: "chart.bar",
                                           description: Text("この期間に記録された稼働時間はありません。"))
                        .frame(height: 200)
                } else {
                    totalsSection
                    dailySection
                    notesSection
                }
            }
            .padding(20)
        }
        .navigationTitle("ダッシュボード")
        .frame(minWidth: 640, minHeight: 480)
    }

    // MARK: - 操作部

    private var controls: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { shiftMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                .help("前の月")
            Text(DashboardView.monthLabel(for: selectedMonth))
                .font(.headline).monospacedDigit().frame(minWidth: 110)
            Button { shiftMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                .help("次の月").disabled(isCurrentMonth)
            Button("今月") { selectedMonth = DashboardView.currentMonthStart }
                .disabled(isCurrentMonth)
            Spacer()
            projectFilterMenu
            Menu {
                Button("時間別 CSV") { exportCSV() }
                Button("作業内容別 CSV") { exportNoteSummaryCSV() }
            } label: {
                Label("CSV 出力", systemImage: "square.and.arrow.up")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let exportMessage {
                Text(exportMessage).font(.caption).foregroundStyle(.secondary).offset(y: 18)
            }
        }
    }

    /// プロジェクト絞り込み用のメニュー。「すべて」または 1 つを選択する。
    private var projectFilterMenu: some View {
        Menu {
            Picker("プロジェクト", selection: $selectedProjectID) {
                Text("すべてのプロジェクト").tag(UUID?.none)
                ForEach(projects) { project in
                    Text(project.name).tag(UUID?.some(project.id))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(projectFilterLabel, systemImage: "line.3.horizontal.decrease.circle")
        }
        .help("表示するプロジェクトを絞り込む")
    }

    /// フィルタメニューのラベル。選択状況に応じて表示を変える。
    private var projectFilterLabel: String {
        guard let id = selectedProjectID,
              let project = projects.first(where: { $0.id == id }) else {
            return "すべてのプロジェクト"
        }
        return project.name
    }

    // MARK: - 合計

    private var totalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プロジェクト別 合計稼働時間").font(.headline)
            Chart(projectTotals) { total in
                BarMark(
                    x: .value("時間", DurationFormatter.hours(from: total.seconds)),
                    y: .value("プロジェクト", total.name)
                )
                .foregroundStyle(by: .value("プロジェクト", total.name))
                .annotation(position: .trailing) {
                    Text(DurationFormatter.compactHours(from: total.seconds))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartForegroundStyleScale(range: colorRange(for: projectTotals.map(\.name)))
            .chartXAxisLabel("時間")
            .chartLegend(.hidden)
            .frame(height: max(120, CGFloat(projectTotals.count) * 44))
        }
    }

    // MARK: - 作業内容別

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("作業内容別 稼働時間")
                .font(.headline)
            if noteTotals.count > 1 {
                Text("1つの記録に複数の作業内容がある場合、時間を均等に配分")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Chart(noteTotals) { total in
                BarMark(
                    x: .value("時間", DurationFormatter.hours(from: total.seconds)),
                    y: .value("作業内容", total.note)
                )
                .foregroundStyle(Color.accentColor.opacity(0.75))
                .annotation(position: .trailing) {
                    Text(DurationFormatter.compactHours(from: total.seconds))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxisLabel("時間")
            .chartLegend(.hidden)
            .frame(height: max(120, CGFloat(noteTotals.count) * 32))
        }
    }

    // MARK: - 日次推移

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1日ごとの稼働時間推移").font(.headline)
            Chart(dailyDurations) { item in
                BarMark(
                    x: .value("日付", item.day, unit: .day),
                    y: .value("時間", DurationFormatter.hours(from: item.seconds))
                )
                .foregroundStyle(by: .value("プロジェクト", item.name))
                ForEach(dailyTotals.filter { $0.seconds > 0 }, id: \.day) { total in
                    PointMark(
                        x: .value("日付", total.day, unit: .day),
                        y: .value("時間", DurationFormatter.hours(from: total.seconds))
                    )
                    .opacity(0)
                    .annotation(position: .top) {
                        Text(DurationFormatter.compactHours(from: total.seconds))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartForegroundStyleScale(range: colorRange(for: dailyNames))
            .chartXScale(domain: selectedMonth...monthEnd)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .chartYAxisLabel("時間")
            .frame(height: 260)
        }
    }

    // MARK: - 集計

    fileprivate static var currentMonthStart: Date {
        monthStart(for: Date())
    }

    fileprivate static func monthStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    fileprivate static func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    fileprivate static func fileMonthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private var isCurrentMonth: Bool {
        selectedMonth == DashboardView.currentMonthStart
    }

    private func shiftMonth(by value: Int) {
        let calendar = Calendar.current
        guard let shifted = calendar.date(byAdding: .month, value: value, to: selectedMonth) else { return }
        let next = DashboardView.monthStart(for: shifted)
        selectedMonth = min(next, DashboardView.currentMonthStart)
    }

    private var monthEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
    }

    private var range: ClosedRange<Date> { selectedMonth...monthEnd }

    private var visibleLogs: [TimeLog] {
        guard let id = selectedProjectID else { return logs }
        return logs.filter { $0.project?.id == id }
    }

    private var filteredLogs: [TimeLog] {
        visibleLogs.filter { log in
            let end = log.endDate ?? Date()
            return end >= range.lowerBound && log.startDate <= range.upperBound
        }
    }

    private var projectTotals: [ProjectTotal] {
        ReportAggregator.projectTotals(logs: visibleLogs, in: range)
    }

    private var noteTotals: [NoteTotal] {
        ReportAggregator.noteTotals(logs: visibleLogs, in: range)
    }

    private var dailyDurations: [DailyDuration] {
        ReportAggregator.dailyDurations(logs: visibleLogs, in: range)
    }

    private var dailyTotals: [(day: Date, seconds: TimeInterval)] {
        Dictionary(grouping: dailyDurations, by: \.day)
            .map { (day: $0.key, seconds: $0.value.reduce(0) { $0 + $1.seconds }) }
            .sorted { $0.day < $1.day }
    }

    private var dailyNames: [String] {
        var seen = Set<String>()
        return dailyDurations.compactMap { seen.insert($0.name).inserted ? $0.name : nil }
    }

    private func colorRange(for names: [String]) -> [Color] {
        names.map { name in
            dailyDurations.first { $0.name == name }?.colorHex
                ?? projectTotals.first { $0.name == name }?.colorHex
                ?? "#999999"
        }
        .map { Color(hex: $0) ?? .gray }
    }

    private func exportCSV() {
        handleExport(CSVExportService.export(
            logs: filteredLogs, clipTo: range,
            suggestedName: "timelogs-\(DashboardView.fileMonthLabel(for: selectedMonth)).csv"))
    }

    private func exportNoteSummaryCSV() {
        handleExport(CSVExportService.exportNoteSummary(
            totals: noteTotals,
            suggestedName: "note-summary-\(DashboardView.fileMonthLabel(for: selectedMonth)).csv"))
    }

    private func handleExport(_ result: CSVExportService.ExportResult) {
        switch result {
        case .saved(let url): exportMessage = "保存しました: \(url.lastPathComponent)"
        case .cancelled: exportMessage = nil
        case .failed(let message): exportMessage = "保存に失敗: \(message)"
        }
    }
}
