import SwiftUI

struct MenuBarProjectRow: View {
    let project: Project
    let engine: TimerEngine
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onStartMinutesAgo: (Int) -> Void
    let onSpecifyStartDate: () -> Void

    @State private var isHovered = false

    var body: some View {
        let running = engine.isRunning(project)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    engine.toggle(project)
                } label: {
                    HStack {
                        Circle()
                            .fill(project.color)
                            .opacity(running ? 1 : 0.4)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(project.name)
                            .lineLimit(1)
                        Spacer()
                        if running, let start = engine.runningStartDate(for: project) {
                            TimelineView(.periodic(from: start, by: 1)) { context in
                                Text(DurationFormatter.clockString(from: context.date.timeIntervalSince(start)))
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(running ? "「\(project.name)」を停止" : "「\(project.name)」を開始")
                .accessibilityValue(running ? "計測中" : "停止中")

                if !running {
                    Button {
                        onToggleExpanded()
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel("「\(project.name)」の開始メニュー")
                    .accessibilityValue(isExpanded ? "展開中" : "")
                    .accessibilityHint("過去の時刻から開始するオプションを表示します")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(running
                          ? project.color.opacity(isHovered ? 0.25 : 0.15)
                          : Color.primary.opacity(isHovered ? 0.08 : 0))
            )
            .onHover { isHovered = $0 }

            if isExpanded && !running {
                retroactiveStartOptions
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var retroactiveStartOptions: some View {
        VStack(spacing: 0) {
            OptionButton("5 分前から開始") { onStartMinutesAgo(5) }
            OptionButton("10 分前から開始") { onStartMinutesAgo(10) }
            OptionButton("15 分前から開始") { onStartMinutesAgo(15) }
            Divider().padding(.horizontal, 6)
            OptionButton("開始時刻を指定…") { onSpecifyStartDate() }
        }
        .padding(.leading, 20)
        .padding(.vertical, 4)
    }
}

private struct OptionButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
        )
        .onHover { isHovered = $0 }
    }
}
