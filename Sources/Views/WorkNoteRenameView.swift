import SwiftUI

/// 既存の作業内容タグを 1 つ選び、全期間の全記録にわたって別の文言へ置き換えるシート。
struct WorkNoteRenameView: View {
    /// 置換候補の抽出と件数プレビューに使う全ログ。
    let logs: [TimeLog]
    /// (旧文言, 新文言) を受け取る。実際の置換は呼び出し側が行う。
    let onRename: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var target: String?
    @State private var newText = ""
    @State private var showingConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("作業内容を一括変更")
                .font(.system(.title3, design: .rounded).bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("変更する作業内容")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("変更する作業内容", selection: $target) {
                    Text("選択してください").tag(String?.none)
                    ForEach(candidates, id: \.self) { candidate in
                        Text(candidate).tag(String?.some(candidate))
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("新しい作業内容")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("文言を入力", text: $newText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                Text(affectedCount > 0
                     ? "\(affectedCount) 件の記録が変更されます"
                     : "対象の記録がありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer().frame(height: 10)

            HStack {
                Button("キャンセル") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("変更") { showingConfirm = true }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canRename)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onChange(of: target) { _, newValue in
            // 多くは部分的な言い換えなので、選択した文言を編集の起点にする。
            newText = newValue ?? ""
        }
        .confirmationDialog("作業内容を一括変更しますか？", isPresented: $showingConfirm) {
            Button("変更", role: .destructive) {
                guard let target, canRename else { return }
                onRename(target, trimmedNewText)
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let target {
                Text("「\(target)」を「\(trimmedNewText)」に変更します。\(affectedCount) 件の記録が対象です。この操作は取り消せません。")
            }
        }
    }

    /// 全期間の記録から抽出した作業内容の候補（件数上限なし）。
    private var candidates: [String] {
        WorkNoteSuggestions.candidates(from: logs, limit: .max)
    }

    private var trimmedNewText: String {
        newText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 対象タグを含む記録の件数。
    private var affectedCount: Int {
        guard let target else { return 0 }
        return logs.filter { log in
            log.notes.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines) == target }
        }.count
    }

    private var canRename: Bool {
        guard let target else { return false }
        return !trimmedNewText.isEmpty && trimmedNewText != target
    }
}
