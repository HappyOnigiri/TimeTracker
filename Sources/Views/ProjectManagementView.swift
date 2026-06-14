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

    var body: some View {
        VStack(spacing: 0) {
            list
            Divider()
            toolbar
        }
        .frame(minWidth: 420, minHeight: 360)
        .sheet(isPresented: $showingEditor) {
            ProjectEditorView(project: editing) { name, colorHex in
                save(name: name, colorHex: colorHex)
            }
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(projects) { project in
                HStack {
                    Circle().fill(project.color).frame(width: 10, height: 10)
                    Text(project.name)
                    Spacer()
                    if engine.isRunning(project) {
                        Text("測定中").font(.caption).foregroundStyle(.green)
                    }
                }
                .tag(project.id)
                .contextMenu {
                    Button("編集") { beginEdit(project) }
                    Button("削除", role: .destructive) { delete(project) }
                }
            }
        }
        .overlay {
            if projects.isEmpty {
                ContentUnavailableView("プロジェクトがありません", systemImage: "folder.badge.plus",
                                       description: Text("下の「＋」から追加してください。"))
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Button {
                beginAdd()
            } label: {
                Image(systemName: "plus").toolbarIconShape()
            }
            Button {
                if let project = selectedProject { beginEdit(project) }
            } label: {
                Image(systemName: "pencil").toolbarIconShape()
            }
            .disabled(selectedProject == nil)
            Button {
                if let project = selectedProject { delete(project) }
            } label: {
                Image(systemName: "minus").toolbarIconShape()
            }
            .disabled(selectedProject == nil)
            Spacer()
        }
        .padding(8)
        .buttonStyle(.borderless)
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

private extension Image {
    /// ツールバーアイコンのクリック領域を、アイコン周辺の余白まで広げる。
    func toolbarIconShape() -> some View {
        self
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
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
        VStack(alignment: .leading, spacing: 16) {
            Text(project == nil ? "プロジェクトを追加" : "プロジェクトを編集")
                .font(.headline)
            TextField("プロジェクト名", text: $name)
                .textFieldStyle(.roundedBorder)
            colorPicker
            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }
                Button("保存") {
                    onSave(name, colorHex)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private var colorPicker: some View {
        HStack(spacing: 8) {
            ForEach(ProjectPalette.colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex) ?? .gray)
                    .frame(width: 22, height: 22)
                    .overlay {
                        if hex == colorHex {
                            Circle().stroke(Color.primary, lineWidth: 2)
                        }
                    }
                    .onTapGesture { colorHex = hex }
            }
        }
    }
}
