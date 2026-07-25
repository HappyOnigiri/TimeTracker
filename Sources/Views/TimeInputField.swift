import SwiftUI

struct TimeInputField: View {
    @Binding var date: Date
    let referenceDate: Date

    @FocusState private var isFocused: Bool
    @State private var text: String = ""
    @State private var isInvalid: Bool = false
    @State private var resetTask: Task<Void, Never>?

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    var body: some View {
        TextField("0:00", text: $text)
            .textFieldStyle(.roundedBorder)
            .font(.body.monospacedDigit())
            .frame(width: 60)
            .focused($isFocused)
            .overlay {
                if isInvalid {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.red, lineWidth: 1.5)
                }
            }
            .onAppear { text = Self.displayFormatter.string(from: date) }
            .onChange(of: date) { _, newValue in
                guard !isFocused else { return }
                text = Self.displayFormatter.string(from: newValue)
            }
            .onChange(of: text) { _, newValue in
                applyEdit(newValue)
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commitText() }
            }
            .onSubmit { commitText() }
    }

    /// 入力の 1 文字ごとに Date へ反映する。
    /// フォーカスが残ったまま確定ボタン（保存/開始）を押しても編集内容が失われないようにするため。
    ///
    /// date の同期による text 更新でも呼ばれるが、その場合は分単位で同値になり `unchanged` として無視される。
    private func applyEdit(_ input: String) {
        switch TimeInputCommit.evaluate(text: input, current: date, referenceDate: referenceDate) {
        case .updated(let newDate):
            cancelInvalidReset()
            isInvalid = false
            date = newDate
        case .unchanged:
            cancelInvalidReset()
            isInvalid = false
        case .invalid:
            // 入力途中なのでエラー表示はせず、確定時に判定する。
            break
        }
    }

    private func commitText() {
        cancelInvalidReset()
        switch TimeInputCommit.evaluate(text: text, current: date, referenceDate: referenceDate) {
        case .updated(let newDate):
            isInvalid = false
            date = newDate
            text = Self.displayFormatter.string(from: newDate)
        case .unchanged:
            isInvalid = false
            text = Self.displayFormatter.string(from: date)
        case .invalid:
            isInvalid = true
            resetTask = Task {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                isInvalid = false
                text = Self.displayFormatter.string(from: date)
            }
        }
    }

    private func cancelInvalidReset() {
        resetTask?.cancel()
        resetTask = nil
    }
}
