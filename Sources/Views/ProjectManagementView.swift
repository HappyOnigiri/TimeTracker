import SwiftData
import SwiftUI

/// プロジェクトの追加・編集・削除を行う管理画面。
struct ProjectManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var engine
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    @State private var selection: Project.ID?
    @State private var editing: Project?
    @State private var showingEditor = false
    @State private var projectToDelete: Project?
    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            list
            Divider()
            toolbar
        }
        .frame(minWidth: 420, minHeight: 360)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showingEditor) {
            ProjectEditorView(project: editing) { name, colorHex in
                save(name: name, colorHex: colorHex)
            }
        }
        .alert("プロジェクトの削除", isPresented: $showingDeleteConfirm, presenting: projectToDelete) { project in
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) { delete(project) }
        } message: { project in
            Text("「\(project.name)」を削除してもよろしいですか？この操作は取り消せません。")
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(projects) { project in
                HStack(spacing: 12) {
                    Circle()
                        .fill(project.color)
                        .frame(width: 12, height: 12)
                        .shadow(color: project.color.opacity(0.4), radius: 2, x: 0, y: 1)

                    Text(project.name)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)

                    Spacer()

                    if engine.isRunning(project) {
                        runningBadge(for: project)
                    }
                }
                .padding(.vertical, 6)
                .tag(project.id)
                .contextMenu {
                    Button("編集") { beginEdit(project) }
                    Button("削除", role: .destructive) { confirmDelete(project) }
                }
            }
        }
        .listStyle(.inset)
        .overlay {
            if projects.isEmpty {
                ContentUnavailableView("プロジェクトがありません", systemImage: "folder.badge.plus",
                                       description: Text("下の「＋」から追加してください。"))
            }
        }
    }

    @ViewBuilder
    private func runningBadge(for project: Project) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
            if let start = engine.runningStartDate(for: project) {
                TimelineView(.periodic(from: start, by: 1)) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    Text(DurationFormatter.clockString(from: elapsed))
                        .font(.caption.monospacedDigit())
                        .bold()
                }
            } else {
                Text("測定中")
                    .font(.caption)
                    .bold()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.15))
        .foregroundStyle(.green)
        .clipShape(Capsule())
    }

    private var toolbar: some View {
        HStack {
            Button(action: beginAdd) {
                Label("追加", systemImage: "plus.circle.fill")
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)

            Spacer()

            if selectedProject != nil {
                HStack(spacing: 16) {
                    Button {
                        if let project = selectedProject { beginEdit(project) }
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("編集")

                    Button {
                        if let project = selectedProject { confirmDelete(project) }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("削除")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var selectedProject: Project? {
        projects.first { $0.id == selection }
    }

    private func beginAdd() {
        editing = nil
        showingEditor = true
    }

    private func beginEdit(_ project: Project) {
        editing = project
        showingEditor = true
    }

    private func confirmDelete(_ project: Project) {
        projectToDelete = project
        showingDeleteConfirm = true
    }

    private func save(name: String, colorHex: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let editing {
            editing.name = trimmed
            editing.colorHex = colorHex
        } else {
            let order = (projects.map(\.sortOrder).max() ?? -1) + 1
            context.insert(Project(name: trimmed, colorHex: colorHex, sortOrder: order))
        }
        try? context.save()
    }

    private func delete(_ project: Project) {
        engine.stop(project)
        context.delete(project)
        try? context.save()
    }
}

/// プロジェクトの新規作成/編集シート。
private struct ProjectEditorView: View {
    let project: Project?
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var colorHex: String

    init(project: Project?, onSave: @escaping (String, String) -> Void) {
        self.project = project
        self.onSave = onSave
        _name = State(initialValue: project?.name ?? "")
        _colorHex = State(initialValue: project?.colorHex ?? ProjectPalette.colors[0])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(project == nil ? "プロジェクトを追加" : "プロジェクトを編集")
                .font(.system(.title3, design: .rounded).bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("プロジェクト名")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("名前を入力", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("テーマカラー")
                    .font(.caption)
                    .foregroundColor(.secondary)
                colorPicker
            }

            Spacer().frame(height: 10)

            HStack {
                Button("キャンセル") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    onSave(name, colorHex)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private var colorPicker: some View {
        HStack(spacing: 12) {
            ForEach(ProjectPalette.colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex) ?? .gray)
                    .frame(width: 24, height: 24)
                    .shadow(color: (Color(hex: hex) ?? .gray).opacity(0.3), radius: 2, x: 0, y: 1)
                    .overlay {
                        if hex == colorHex {
                            Circle()
                                .stroke(Color.primary.opacity(0.8), lineWidth: 3)
                                .padding(-4)
                        }
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            colorHex = hex
                        }
                    }
            }
        }
        .padding(.vertical, 4)
    }
}
