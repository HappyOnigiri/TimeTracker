import SwiftData
import SwiftUI

struct TimeLogPopoverEditor: View {
    let log: TimeLog
    let projects: [Project]
    let onSave: (Project, Date, Date, [String]) -> Void
    let onDelete: (TimeLog) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TimeLog.startDate) private var allLogs: [TimeLog]
    @State private var selectedProjectID: UUID?
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes: [String]
    @FocusState private var startFocused: Bool

    init(log: TimeLog, projects: [Project],
         onSave: @escaping (Project, Date, Date, [String]) -> Void,
         onDelete: @escaping (TimeLog) -> Void) {
        self.log = log
        self.projects = projects
        self.onSave = onSave
        self.onDelete = onDelete
        _selectedProjectID = State(initialValue: log.project?.id)
        _startDate = State(initialValue: log.startDate)
        _endDate = State(initialValue: log.endDate ?? log.startDate.addingTimeInterval(3600))
        _notes = State(initialValue: log.notes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("プロジェクト", selection: $selectedProjectID) {
                ForEach(projects) { project in
                    Text(project.name).tag(UUID?.some(project.id))
                }
            }
            .labelsHidden()

            HStack(spacing: 6) {
                TimeInputField(date: $startDate, referenceDate: startDate)
                    .focused($startFocused)
                Text("〜")
                    .foregroundStyle(.secondary)
                TimeInputField(date: $endDate, referenceDate: endDate)
                Spacer()
                Text(DurationFormatter.string(from: endDate.timeIntervalSince(startDate)))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .onChange(of: startDate) { _, newValue in
                if endDate < newValue { endDate = newValue }
            }
            .onChange(of: endDate) { _, newValue in
                if newValue < startDate { endDate = startDate }
            }

            WorkNoteInputView(
                notes: $notes,
                suggestions: WorkNoteSuggestions.candidates(from: allLogs)
            )

            HStack {
                Button("削除", role: .destructive) {
                    dismiss()
                    onDelete(log)
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
        .padding(16)
        .frame(width: 300)
        .onAppear { startFocused = true }
    }
}

extension View {
    // swiftlint:disable:next function_parameter_count
    func blockPopover(
        isPresented: Binding<Bool>,
        anchorRect: CGRect,
        log: TimeLog, projects: [Project],
        onSave: @escaping (Project, Date, Date, [String]) -> Void,
        onDelete: @escaping (TimeLog) -> Void
    ) -> some View {
        popover(isPresented: isPresented,
                attachmentAnchor: .rect(.rect(anchorRect)),
                arrowEdge: .bottom) {
            TimeLogPopoverEditor(
                log: log, projects: projects,
                onSave: onSave, onDelete: onDelete
            )
        }
    }
}
