import SwiftUI

struct RetroactiveStartView: View {
    @Environment(\.locale) private var locale
    let project: Project
    let engine: TimerEngine
    let onDismiss: () -> Void

    @State private var selectedStartDate: Date
    @State private var errorMessage: String?

    init(project: Project, engine: TimerEngine, onDismiss: @escaping () -> Void) {
        self.project = project
        self.engine = engine
        self.onDismiss = onDismiss
        let now = Date()
        _selectedStartDate = State(initialValue: Self.startOfMinute(now))
        _errorMessage = State(initialValue: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("開始時刻を指定")
                .font(.system(.title3, design: .rounded).bold())

            VStack(alignment: .leading, spacing: 4) {
                Text("プロジェクト")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(project.name)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("開始時刻")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    DatePicker(
                        "開始日",
                        selection: normalizedStartDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                    TimeInputField(date: normalizedStartDate, referenceDate: selectedStartDate)
                }
                Text("現在以前の日時を指定してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer().frame(height: 10)

            HStack {
                Button("キャンセル") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("開始", action: start)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedStartDate > Date())
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private var normalizedStartDate: Binding<Date> {
        Binding(
            get: { selectedStartDate },
            set: { newValue in
                selectedStartDate = Self.startOfMinute(newValue)
                errorMessage = nil
            }
        )
    }

    private func start() {
        let now = Date()
        let startDate = Self.startOfMinute(selectedStartDate)
        guard startDate <= now else {
            errorMessage = TimerEngine.RetroactiveStartResult.futureStartDate
                .retroactiveStartErrorMessage(locale: locale)
            return
        }

        let result = engine.startRetroactively(project, at: startDate, now: now)
        if result == .started {
            onDismiss()
        } else {
            errorMessage = result.retroactiveStartErrorMessage(locale: locale)
        }
    }

    private static func startOfMinute(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .minute, for: date)?.start ?? date
    }
}

extension TimerEngine.RetroactiveStartResult {
    func retroactiveStartErrorMessage(locale: Locale) -> String? {
        switch self {
        case .started:
            nil
        case .futureStartDate:
            L10n.string("開始時刻は現在以前を指定してください。", locale: locale)
        case .alreadyRunning:
            L10n.string("このプロジェクトはすでに計測中です。", locale: locale)
        case .anotherProjectIsRunning:
            L10n.string("同時測定が無効のため、別のプロジェクトを計測中は遡って開始できません。", locale: locale)
        case .engineNotConfigured:
            L10n.string("タイマーを開始できませんでした。", locale: locale)
        }
    }
}
