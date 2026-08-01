import SwiftUI

struct MenuBarProjectRow: View {
    @Environment(\.locale) private var locale
    let project: Project
    let engine: TimerEngine
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onStartMinutesAgo: (Int) -> Void
    let onSpecifyStartDate: () -> Void

    @State private var isHovered = false
    @State private var isMenuHovered = false

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
                .accessibilityLabel(
                    running
                        ? String(
                            format: L10n.string("project.stop_accessibility", locale: locale),
                            locale: locale, project.name
                        )
                        : String(
                            format: L10n.string("project.start_accessibility", locale: locale),
                            locale: locale, project.name
                        )
                )
                .accessibilityValue(
                    running
                        ? L10n.string("計測中", locale: locale)
                        : L10n.string("停止中", locale: locale)
                )

                if !running {
                    Button {
                        onToggleExpanded()
                    } label: {
                        // ellipsis の内在サイズは 14x5pt しかないため、行の高さいっぱいまで
                        // 明示的に広げてクリック範囲を確保する（fixedSize は縦を潰すので使わない）。
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(isMenuHovered ? 0.08 : 0))
                    )
                    .onHover { isMenuHovered = $0 }
                    .accessibilityLabel(
                        String(
                            format: L10n.string("project.start_menu_accessibility", locale: locale),
                            locale: locale, project.name
                        )
                    )
                    .accessibilityValue(
                        isExpanded ? L10n.string("展開中", locale: locale) : ""
                    )
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
    let title: LocalizedStringResource
    let action: () -> Void
    @State private var isHovered = false

    init(_ title: LocalizedStringResource, action: @escaping () -> Void) {
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
