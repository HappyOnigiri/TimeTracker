import SwiftData
import SwiftUI

struct TimeLogEditorView: View {
    let log: TimeLog?
    let projects: [Project]
    let defaultDay: Date
    let onSave: (Project, Date, Date, [String]) -> Void
    let onDelete: ((TimeLog) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TimeLog.startDate) private var allLogs: [TimeLog]
    @State private var selectedProjectID: UUID?
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes: [String]

    init(log: TimeLog?,
         projects: [Project],
         defaultDay: Date,
         onSave: @escaping (Project, Date, Date, [String]) -> Void,
         onDelete: ((TimeLog) -> Void)? = nil) {
        self.log = log
        self.projects = projects
        self.defaultDay = defaultDay
        self.onSave = onSave
        self.onDelete = onDelete

        if let log {
            _selectedProjectID = State(initialValue: log.project?.id)
            _startDate = State(initialValue: log.startDate)
            _endDate = State(initialValue: log.endDate ?? log.startDate.addingTimeInterval(3600))
            _notes = State(initialValue: log.notes)
        } else {
            let calendar = Calendar.current
            let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDay) ?? defaultDay
            _selectedProjectID = State(initialValue: projects.first?.id)
            _startDate = State(initialValue: start)
            _endDate = State(initialValue: start.addingTimeInterval(3600))
            _notes = State(initialValue: [])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(log == nil ? "記録を追加" : "記録を編集")
                .font(.system(.title3, design: .rounded).bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("プロジェクト")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("プロジェクト", selection: $selectedProjectID) {
                    ForEach(projects) { project in
                        Text(project.name).tag(UUID?.some(project.id))
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("開始")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    DatePicker("", selection: $startDate, displayedComponents: [.date])
                        .labelsHidden()
                    TimeInputField(date: $startDate, referenceDate: startDate)
                }
                .onChange(of: startDate) { _, newValue in
                    if endDate < newValue { endDate = newValue }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("終了")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date])
                        .labelsHidden()
                    TimeInputField(date: $endDate, referenceDate: endDate)
                }
                .onChange(of: endDate) { _, newValue in
                    if newValue < startDate { endDate = startDate }
                }
            }

            HStack {
                Text("所要時間")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(DurationFormatter.string(from: endDate.timeIntervalSince(startDate)))
                    .font(.callout.monospacedDigit())
                    .fontWeight(.medium)
            }

            WorkNoteInputView(
                notes: $notes,
                suggestions: WorkNoteSuggestions.candidates(from: allLogs)
            )

            Spacer().frame(height: 10)

            HStack {
                Button("キャンセル") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if let log, let onDelete {
                    Button("削除", role: .destructive) {
                        dismiss()
                        onDelete(log)
                    }
                }
                Spacer()
                Button("保存") {
                    if let project = projects.first(where: { $0.id == selectedProjectID }) {
                        onSave(project, startDate, endDate, notes)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedProjectID == nil)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
