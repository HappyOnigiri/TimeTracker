import Charts
import SwiftData
import SwiftUI

/// 稼働時間レポートのダッシュボード。合計と日次推移をグラフ表示し、CSV 出力も行う。
struct DashboardView: View {
    @Query private var logs: [TimeLog]

    @State private var startDate: Date = DashboardView.defaultStart
    @State private var endDate: Date = Date()
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
            DatePicker("開始", selection: $startDate, displayedComponents: .date)
            DatePicker("終了", selection: $endDate, displayedComponents: .date)
            Button("直近1ヶ月") {
                startDate = DashboardView.defaultStart
                endDate = Date()
            }
            Spacer()
            Button("CSV 出力", systemImage: "square.and.arrow.up") {
                exportCSV()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let exportMessage {
                Text(exportMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .offset(y: 18)
            }
        }
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
                    Text(DurationFormatter.string(from: total.seconds))
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
            }
            .chartForegroundStyleScale(range: colorRange(for: dailyNames))
            .chartYAxisLabel("時間")
            .frame(height: 260)
        }
    }

    // MARK: - 集計

    private static var defaultStart: Date {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return calendar.startOfDay(for: monthAgo)
    }

    private var range: ClosedRange<Date> {
        let calendar = Calendar.current
        let lower = calendar.startOfDay(for: min(startDate, endDate))
        let upperBase = calendar.startOfDay(for: max(startDate, endDate))
        let upper = calendar.date(byAdding: .day, value: 1, to: upperBase) ?? upperBase
        return lower...upper
    }

    private var filteredLogs: [TimeLog] {
        logs.filter { log in
            let end = log.endDate ?? Date()
            return end >= range.lowerBound && log.startDate <= range.upperBound
        }
    }

    private var projectTotals: [ProjectTotal] {
        ReportAggregator.projectTotals(logs: logs, in: range)
    }

    private var dailyDurations: [DailyDuration] {
        ReportAggregator.dailyDurations(logs: logs, in: range)
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
        let result = CSVExportService.export(logs: filteredLogs)
        switch result {
        case .saved(let url):
            exportMessage = "保存しました: \(url.lastPathComponent)"
        case .cancelled:
            exportMessage = nil
        case .failed(let message):
            exportMessage = "保存に失敗: \(message)"
        }
    }
}
