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
            .onChange(of: isFocused) { _, focused in
                if !focused { commitText() }
            }
            .onSubmit { commitText() }
    }

    private func commitText() {
        resetTask?.cancel()
        resetTask = nil
        if let parsed = TimeInputParser.parse(text) {
            isInvalid = false
            let newDate = TimeInputParser.applyToDate(parsed, referenceDate: referenceDate)
            date = newDate
            text = Self.displayFormatter.string(from: newDate)
        } else {
            isInvalid = true
            resetTask = Task {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                isInvalid = false
                text = Self.displayFormatter.string(from: date)
            }
        }
    }
}
