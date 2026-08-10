import SwiftData
import SwiftUI

/// 作業内容の文言と関連プロジェクトを編集するシート。
struct WorkNoteManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkNote.text) private var workNotes: [WorkNote]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \TimeLog.startDate) private var logs: [TimeLog]

    @State private var selectedID: UUID?
    @State private var text = ""
    @State private var selectedProjectIDs: Set<UUID> = []
    @State private var showingRenameConfirmation = false
    @State private var showingMergeConfirmation = false
    @State private var errorMessage = ""
    @State private var showingError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("作業内容を管理")
                .font(.system(.title3, design: .rounded).bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("変更する作業内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("変更する作業内容", selection: $selectedID) {
                    Text("選択してください").tag(UUID?.none)
                    ForEach(workNotes) { item in
                        Text(item.text).tag(UUID?.some(item.id))
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("作業内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("文言を入力", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .disabled(selectedNote == nil)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("紐づくプロジェクト")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(projects) { project in
                            Toggle(project.name, isOn: projectBinding(project.id))
                                .toggleStyle(.checkbox)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
                .disabled(selectedNote == nil)
            }

            HStack {
                Button("キャンセル") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") { prepareToSave() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onChange(of: selectedID) { _, _ in loadSelection() }
        .confirmationDialog("作業内容を変更しますか？", isPresented: $showingRenameConfirmation) {
            Button("変更", role: .destructive) { save() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let selectedNote {
                Text(renameConfirmationMessage(from: selectedNote.text))
            }
        }
        .confirmationDialog("同名の作業内容へ統合しますか？", isPresented: $showingMergeConfirmation) {
            Button("統合", role: .destructive) { save() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let selectedNote {
                Text(mergeConfirmationMessage(from: selectedNote.text))
            }
        }
        .alert("保存に失敗しました", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private var selectedNote: WorkNote? {
        guard let selectedID else { return nil }
        return workNotes.first { $0.id == selectedID }
    }

    private var normalizedText: String {
        WorkNoteRenaming.key(text)
    }

    private var originalProjectIDs: Set<UUID> {
        Set(selectedNote?.projects.map(\.id) ?? [])
    }

    private var textChanged: Bool {
        guard let selectedNote else { return false }
        return normalizedText != WorkNoteRenaming.key(selectedNote.text)
    }

    private var canSave: Bool {
        guard selectedNote != nil, !normalizedText.isEmpty else { return false }
        return textChanged || selectedProjectIDs != originalProjectIDs
    }

    private var affectedCount: Int {
        guard let selectedNote else { return 0 }
        return logs.filter { WorkNoteRenaming.matches(notes: $0.notes, tag: selectedNote.text) }.count
    }

    private var mergesWithExisting: Bool {
        guard let selectedID else { return false }
        return workNotes.contains {
            $0.id != selectedID && WorkNoteRenaming.key($0.text) == normalizedText
        }
    }

    private func projectBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedProjectIDs.contains(id) },
            set: { isSelected in
                if isSelected {
                    selectedProjectIDs.insert(id)
                } else {
                    selectedProjectIDs.remove(id)
                }
            }
        )
    }

    private func loadSelection() {
        guard let selectedNote else {
            text = ""
            selectedProjectIDs = []
            return
        }
        text = selectedNote.text
        selectedProjectIDs = Set(selectedNote.projects.map(\.id))
    }

    private func prepareToSave() {
        guard canSave else { return }
        if !textChanged {
            save()
        } else if mergesWithExisting {
            showingMergeConfirmation = true
        } else {
            showingRenameConfirmation = true
        }
    }

    private func save() {
        guard let selectedID else { return }
        do {
            try WorkNoteCatalog.update(
                id: selectedID,
                text: normalizedText,
                projectIDs: selectedProjectIDs,
                in: context
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func renameConfirmationMessage(from oldText: String) -> String {
        String(
            format: L10n.string("worknote.rename.confirmation", locale: locale),
            locale: locale,
            oldText,
            normalizedText,
            affectedCount
        )
    }

    private func mergeConfirmationMessage(from oldText: String) -> String {
        String(
            format: L10n.string("worknote.merge.confirmation", locale: locale),
            locale: locale,
            oldText,
            normalizedText,
            affectedCount
        )
    }
}
