import SwiftData
import SwiftUI

/// メニューバーから開くポップオーバーの内容。
struct MenuBarContentView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
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

    private var header: some View {
        HStack {
            Image(systemName: engine.isAnyRunning ? "stopwatch.fill" : "stopwatch")
                .foregroundStyle(engine.isAnyRunning ? Color.accentColor : Color.secondary)
            Text(engine.isAnyRunning ? "測定中" : "全停止中")
                .font(.headline)
            Spacer()
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
        let running = engine.isRunning(project)
        return HStack {
            Circle()
                .fill(project.color)
                .opacity(running ? 1 : 0.4)
                .frame(width: 8, height: 8)
            Text(project.name)
                .lineLimit(1)
            Spacer()
            Button(running ? "停止" : "開始") {
                engine.toggle(project)
            }
            .buttonStyle(.bordered)
            .tint(running ? .red : .accentColor)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if engine.isAnyRunning {
                menuButton("すべて停止", systemImage: "stop.circle") {
                    engine.stopAll()
                }
            }
            menuButton("ダッシュボード…", systemImage: MainTab.dashboard.systemImage) {
                open(.dashboard)
            }
            menuButton("プロジェクト管理…", systemImage: MainTab.projects.systemImage) {
                open(.projects)
            }
            menuButton("設定…", systemImage: MainTab.settings.systemImage) {
                open(.settings)
            }
            Divider()
            menuButton("TimeTracker を終了", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .buttonStyle(.plain)
    }

    private func menuButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 指定タブを選択してメインウィンドウを開く。
    private func open(_ tab: MainTab) {
        navigation.selectedTab = tab
        openWindow(id: WindowID.main)
        NSApp.activate(ignoringOtherApps: true)
    }
}
