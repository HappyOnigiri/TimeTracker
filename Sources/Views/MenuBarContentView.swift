import SwiftData
import SwiftUI

struct MenuBarContentView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @State private var retroactiveStartTarget: Project?
    @State private var retroactiveStartErrorMessage = ""
    @State private var showingRetroactiveStartError = false

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
        .sheet(item: $retroactiveStartTarget) { project in
            RetroactiveStartView(project: project, engine: engine)
        }
        .alert("開始できません", isPresented: $showingRetroactiveStartError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(retroactiveStartErrorMessage)
        }
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
        MenuBarProjectRow(
            project: project,
            engine: engine,
            onStartMinutesAgo: { minutes in
                startRetroactively(project, minutesAgo: minutes)
            },
            onSpecifyStartDate: {
                retroactiveStartTarget = project
            }
        )
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

    private func startRetroactively(_ project: Project, minutesAgo: Int) {
        let now = Date()
        let startDate = now.addingTimeInterval(-TimeInterval(minutesAgo * 60))
        let result = engine.startRetroactively(project, at: startDate, now: now)
        guard result != .started else { return }
        retroactiveStartErrorMessage = result.retroactiveStartErrorMessage ?? "タイマーを開始できませんでした。"
        showingRetroactiveStartError = true
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
