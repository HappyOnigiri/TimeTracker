import SwiftUI

struct MenuBarProjectRow: View {
    let project: Project
    let engine: TimerEngine
    let onStartMinutesAgo: (Int) -> Void
    let onSpecifyStartDate: () -> Void

    @State private var isHovered = false

    var body: some View {
        let running = engine.isRunning(project)

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
                Menu {
                    Button("5 分前から開始") { onStartMinutesAgo(5) }
                    Button("10 分前から開始") { onStartMinutesAgo(10) }
                    Button("15 分前から開始") { onStartMinutesAgo(15) }
                    Divider()
                    Button("開始時刻を指定…", action: onSpecifyStartDate)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .padding(.trailing, 6)
                .accessibilityLabel("「\(project.name)」の開始メニュー")
                .accessibilityHint("開始時刻を選択します")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(running
                      ? project.color.opacity(isHovered ? 0.25 : 0.15)
                      : Color.primary.opacity(isHovered ? 0.08 : 0))
        )
        .onHover { isHovered = $0 }
    }
}
