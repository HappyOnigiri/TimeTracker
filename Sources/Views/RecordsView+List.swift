import SwiftData
import SwiftUI

/// RecordsView のリスト表示の行ビューと CRUD 操作。
extension RecordsView {
    // MARK: - 行

    @ViewBuilder
    func row(for log: TimeLog) -> some View { // swiftlint:disable:this function_body_length
        HStack(spacing: 12) {
            Circle()
                .fill(log.project?.color ?? .gray)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.project?.name ?? "（不明）")
                    .lineLimit(1)
                if !log.notes.isEmpty {
                    Text(log.notes.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 80, alignment: .leading)

            Spacer()

            if log.isRunning {
                Text("計測中")
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            } else {
                TimeInputField(
                    date: Binding(
                        get: { log.startDate },
                        set: { log.startDate = $0; clampEnd(log); try? context.save() }
                    ),
                    referenceDate: log.startDate
                )

                Text("〜")
                    .foregroundStyle(.secondary)

                TimeInputField(
                    date: Binding(
                        get: { log.endDate ?? log.startDate },
                        set: { log.endDate = max($0, log.startDate); try? context.save() }
                    ),
                    referenceDate: log.endDate ?? log.startDate
                )

                Text(DurationFormatter.string(from: log.duration))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 70, alignment: .trailing)

                rowMenu(for: log)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            // 計測中ログは誤編集防止のため操作不可（読み取り専用）。
            if !log.isRunning {
                menuItems(for: log)
            }
        }
    }

    func rowMenu(for log: TimeLog) -> some View {
        Menu {
            menuItems(for: log)
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    func menuItems(for log: TimeLog) -> some View {
        Button("編集…") { editorTarget = .edit(log) }
        Button("複製") { duplicate(log) }
        Button("削除", role: .destructive) { delete(log) }
    }

    // MARK: - 操作

    /// 終了 < 開始にならないよう補正する。
    func clampEnd(_ log: TimeLog) {
        if let end = log.endDate, end < log.startDate {
            log.endDate = log.startDate
        }
    }

    func duplicate(_ log: TimeLog) {
        TimeLogEditing.duplicate(log, in: context)
    }

    func delete(_ log: TimeLog) {
        TimeLogEditing.delete(log, in: context)
    }

    func save(target: EditorTarget, project: Project, start: Date, end: Date, notes: [String]) {
        switch target {
        case .add:
            TimeLogEditing.add(project: project, start: start, end: end, notes: notes, in: context)
        case .edit(let log):
            TimeLogEditing.update(log, project: project, start: start, end: end, notes: notes, in: context)
        }
    }
}
