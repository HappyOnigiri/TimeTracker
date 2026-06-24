import SwiftData
import SwiftUI

struct MenuBarContentView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 320)
    }

    private var emptyState: some View {
        Text("プロジェクトがありません。\n「プロジェクト管理」から追加してください。")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var projectList: some View {
        VStack(spacing: 4) {
            ForEach(projects) { project in
                projectRow(project)
            }
        }
    }

    private func projectRow(_ project: Project) -> some View {
        ProjectRow(project: project, engine: engine)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            MenuButton("ダッシュボード…", systemImage: MainTab.dashboard.systemImage) {
                open(.dashboard)
            }
            MenuButton("記録…", systemImage: MainTab.records.systemImage) {
                open(.records)
            }
            MenuButton("プロジェクト管理…", systemImage: MainTab.projects.systemImage) {
                open(.projects)
            }
            MenuButton("設定…", systemImage: MainTab.settings.systemImage) {
                open(.settings)
            }
            Divider()
            MenuButton("TimeTracker を終了", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func open(_ tab: MainTab) {
        NSApp.keyWindow?.close()
        navigation.selectedTab = tab
        openWindow(id: WindowID.main)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct ProjectRow: View {
    let project: Project
    let engine: TimerEngine
    @State private var isHovered = false

    var body: some View {
        let running = engine.isRunning(project)
        Button {
            engine.toggle(project)
        } label: {
            HStack {
                Circle()
                    .fill(project.color)
                    .opacity(running ? 1 : 0.4)
                    .frame(width: 8, height: 8)
                Text(project.name)
                    .lineLimit(1)
                Spacer()
                if running, let start = engine.runningStartDate(for: project) {
                    TimelineView(.periodic(from: start, by: 1)) { context in
                        Text(DurationFormatter.clockString(from: context.date.timeIntervalSince(start)))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(running
                          ? project.color.opacity(isHovered ? 0.25 : 0.15)
                          : Color.primary.opacity(isHovered ? 0.08 : 0))
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

private struct MenuButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovered = false

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
        )
        .onHover { isHovered = $0 }
    }
}
