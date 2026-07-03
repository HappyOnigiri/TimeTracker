import SwiftData
import SwiftUI

struct WorkNotePromptView: View {
    let engine: TimerEngine
    @Query(sort: \TimeLog.startDate) private var allLogs: [TimeLog]
    @State private var notes: [String] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("作業内容を記録")
                .font(.title2.bold())

            if !projectNames.isEmpty {
                Text(projectNames.joined(separator: "、"))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            WorkNoteInputView(
                notes: $notes,
                suggestions: WorkNoteSuggestions.candidates(from: allLogs)
            )

            HStack(spacing: 16) {
                Button("スキップ") {
                    engine.skipWorkNotes()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)

                Button("保存") {
                    engine.saveWorkNotes(notes)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(32)
        .frame(width: 440)
    }

    private var projectNames: [String] {
        Array(Set(engine.pendingNoteLogs.compactMap { $0.project?.name })).sorted()
    }
}
