import SwiftData
import SwiftUI

/// 記録（TimeLog）を月単位・日付ごとに一覧表示し、インライン編集・追加・削除・複製を行う画面。
struct RecordsView: View {
    @Environment(\.modelContext) var context
    @Query(sort: \TimeLog.startDate) private var logs: [TimeLog]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \ActiveSession.startDate) private var activeSessions: [ActiveSession]

    /// 表示対象の月（その月の 1 日 0:00）。リスト・タイムライン共通。
    @State private var selectedMonth: Date = RecordsView.currentMonthStart
    @State private var viewMode: ViewMode = .timeline
    /// プロジェクト絞り込み（nil＝すべて）。リスト・タイムライン共通。
    @State private var selectedProjectID: UUID?
    @State var editorTarget: EditorTarget?

    /// 表示モード。リスト＝月単位の一覧、タイムライン＝月単位の横軸ドラッグ編集。
    private enum ViewMode: String, CaseIterable, Identifiable {
        case list, timeline
        var id: String { rawValue }
        var title: String {
            switch self {
            case .list: "リスト"
            case .timeline: "タイムライン"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            content
        }
        .frame(minWidth: 480, minHeight: 420)
        .navigationTitle("記録")
        .sheet(item: $editorTarget) { target in
            TimeLogEditorView(
                log: target.log,
                projects: projects,
                defaultDay: target.day,
                onSave: { project, start, end in
                    save(target: target, project: project, start: start, end: end)
                },
                onDelete: target.log.map { log in
                    { _ in delete(log) }
                }
            )
        }
    }

    // MARK: - 操作部

    private var controls: some View {
        HStack(alignment: .center, spacing: 12) {
            Picker("表示", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Divider().frame(height: 18)

            monthNav

            Divider().frame(height: 18)

            projectFilter

            Spacer()

            Button {
                editorTarget = .add(defaultAddDay)
            } label: {
                Label("記録を追加", systemImage: "plus")
            }
            .disabled(projects.isEmpty)
            .help(projects.isEmpty ? "先にプロジェクトを作成してください" : "記録を追加")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 月送りコントロール（リスト・タイムライン共通）。
    private var monthNav: some View {
        HStack(spacing: 12) {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help("前の月")

            Text(RecordsView.monthLabel(for: selectedMonth))
                .font(.headline)
                .monospacedDigit()
                .frame(minWidth: 110)

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .help("次の月")
            .disabled(isCurrentMonth)

            Button("今月") {
                selectedMonth = RecordsView.currentMonthStart
            }
            .disabled(isCurrentMonth)
        }
    }

    /// プロジェクト絞り込みコントロール（リスト・タイムライン共通）。
    private var projectFilter: some View {
        Picker("プロジェクト", selection: $selectedProjectID) {
            Text("すべて").tag(UUID?.none)
            ForEach(projects) { project in
                Text(project.name).tag(UUID?.some(project.id))
            }
        }
        .labelsHidden()
        .fixedSize()
        .help("プロジェクトで絞り込む")
    }

    @ViewBuilder
    private var content: some View {
        if projects.isEmpty {
            ContentUnavailableView("プロジェクトがありません", systemImage: "folder.badge.plus",
                                   description: Text("先にプロジェクトを作成してください。"))
        } else if viewMode == .list {
            listContent
        } else {
            timelineContent
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if groupedDays.isEmpty {
            ContentUnavailableView("記録がありません", systemImage: "list.bullet.rectangle",
                                   description: Text("この月に記録された稼働時間はありません。"))
        } else {
            List {
                ForEach(groupedDays, id: \.day) { group in
                    Section {
                        ForEach(group.logs) { log in
                            row(for: log)
                        }
                    } header: {
                        HStack {
                            Text(RecordsView.dayLabel(for: group.day))
                            Spacer()
                            Text(DurationFormatter.string(from: group.totalSeconds))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    /// タイムラインは稼働がない日も含め当月の全日を表示するため、常に描画する。
    /// 選択中の月に該当するアクティブセッション。
    private var monthActiveSessions: [ActiveSession] {
        let range = selectedMonth..<monthEnd
        return activeSessions.filter { session in
            let end = session.endDate ?? Date()
            return session.startDate < range.upperBound && end > range.lowerBound
        }
    }

    private var timelineContent: some View {
        MonthTimelineView(
            month: selectedMonth, logs: monthLogs, projects: projects,
            activeSessions: monthActiveSessions
        ) { log in
            editorTarget = .edit(log)
        } onAddLog: { project, start, end in
            TimeLogEditing.add(project: project, start: start, end: end, in: context)
        }
    }

    // MARK: - グルーピング

    /// 選択中の月に開始した記録（月＋プロジェクト絞り込み）。
    private var monthLogs: [TimeLog] {
        let range = selectedMonth..<monthEnd
        return logs.filter { log in
            guard range.contains(log.startDate) else { return false }
            if let id = selectedProjectID { return log.project?.id == id }
            return true
        }
    }

    /// 選択中の月に開始した記録を、日付ごとにまとめたもの（日付昇順／日内は開始昇順）。
    private var groupedDays: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: monthLogs) { calendar.startOfDay(for: $0.startDate) }
        return grouped
            .map { day, items in
                DayGroup(
                    day: day,
                    logs: items.sorted { $0.startDate < $1.startDate },
                    totalSeconds: items.reduce(0) { $0 + $1.duration }
                )
            }
            .sorted { $0.day < $1.day }
    }

    /// ＋ボタンで追加する際の初期日。表示中の月なら今日、過去の月ならその月の 1 日。
    private var defaultAddDay: Date {
        isCurrentMonth ? Calendar.current.startOfDay(for: Date()) : selectedMonth
    }

    // MARK: - 月送り

    private var isCurrentMonth: Bool {
        selectedMonth == RecordsView.currentMonthStart
    }

    private func shiftMonth(by value: Int) {
        let calendar = Calendar.current
        guard let shifted = calendar.date(byAdding: .month, value: value, to: selectedMonth) else { return }
        let next = RecordsView.monthStart(for: shifted)
        selectedMonth = min(next, RecordsView.currentMonthStart)
    }

    /// 選択中の月の終端（翌月 1 日 0:00）。
    private var monthEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
    }

    // MARK: - 日付ユーティリティ

    /// 今月の 1 日 0:00。
    private static var currentMonthStart: Date {
        monthStart(for: Date())
    }

    /// 指定日が属する月の 1 日 0:00。
    private static func monthStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    /// 「2026年6月」の日本式月ラベル。
    private static func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    /// 「6月15日(日)」の日本式日付ラベル。
    private static func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }
}

/// 日付ごとにまとめた記録グループ。
private struct DayGroup {
    let day: Date
    let logs: [TimeLog]
    let totalSeconds: TimeInterval
}

/// シート表示の対象。新規追加（対象日）か既存編集か。
enum EditorTarget: Identifiable {
    case add(Date)
    case edit(TimeLog)

    var id: String {
        switch self {
        case .add(let day): "add-\(day.timeIntervalSinceReferenceDate)"
        case .edit(let log): "edit-\(log.id.uuidString)"
        }
    }

    var log: TimeLog? {
        switch self {
        case .add: nil
        case .edit(let log): log
        }
    }

    var day: Date {
        switch self {
        case .add(let day): day
        case .edit(let log): log.startDate
        }
    }
}
