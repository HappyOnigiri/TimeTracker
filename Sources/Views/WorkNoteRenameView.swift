import SwiftUI

/// 既存の作業内容タグを 1 つ選び、全期間の全記録にわたって別の文言へ置き換えるシート。
struct WorkNoteRenameView: View {
    @Environment(\.locale) private var locale
    /// 置換候補の抽出と件数プレビューに使う全ログ。
    let logs: [TimeLog]
    /// (旧文言, 新文言) を受け取り、変更した記録の件数を返す。実際の置換は呼び出し側が行う。
    let onRename: (String, String) -> Int

    @Environment(\.dismiss) private var dismiss
    @State private var target: String?
    @State private var newText = ""
    @State private var showingConfirm = false
    @State private var showingNoChange = false
    /// 全期間の記録から抽出した作業内容の候補（件数上限なし）。表示時に一度だけ求める。
    @State private var candidates: [String] = []
    /// 対象タグを含む記録の件数。対象の切り替え時だけ求め直す。
    @State private var affectedCount = 0

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
                Text(countLabel)
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
        .onAppear {
            candidates = WorkNoteSuggestions.candidates(from: logs, limit: .max)
        }
        .onChange(of: target) { _, newValue in
            // 多くは部分的な言い換えなので、選択した文言を編集の起点にする。
            newText = newValue ?? ""
            affectedCount = newValue.map(countLogs(containing:)) ?? 0
        }
        .confirmationDialog("作業内容を一括変更しますか？", isPresented: $showingConfirm) {
            Button("変更", role: .destructive) { rename() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let target {
                Text("「\(target)」を「\(trimmedNewText)」に変更します。\(affectedCount) 件の記録が対象です。この操作は取り消せません。")
            }
        }
        .alert("変更された記録はありません", isPresented: $showingNoChange) {
            Button("OK") {}
        } message: {
            Text("記録が他の画面で変更された可能性があります。対象の作業内容を選び直してください。")
        }
    }

    private func rename() {
        guard let target, canRename else { return }
        if onRename(target, trimmedNewText) > 0 {
            dismiss()
        } else {
            // 取り消せない操作なので、想定と違って 1 件も変わらなかったときは黙って閉じない。
            affectedCount = countLogs(containing: target)
            showingNoChange = true
        }
    }

    /// 件数表示。未選択と対象 0 件は原因が違うので、同じ文言にしない。
    private var countLabel: String {
        guard target != nil else {
            return L10n.string("変更する作業内容を選択してください", locale: locale)
        }
        guard affectedCount > 0 else {
            return L10n.string("対象の記録がありません", locale: locale)
        }
        return String(
            format: L10n.string("rename.affected_count", locale: locale),
            locale: locale, affectedCount
        )
    }

    private var trimmedNewText: String {
        newText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 対象タグを含む記録の件数。一致規則は WorkNoteRenaming と共有する。
    private func countLogs(containing tag: String) -> Int {
        logs.filter { WorkNoteRenaming.matches(notes: $0.notes, tag: tag) }.count
    }

    private var canRename: Bool {
        guard let target else { return false }
        return !trimmedNewText.isEmpty && trimmedNewText != target
    }
}
