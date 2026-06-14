import SwiftUI

/// ダッシュボード・プロジェクト管理・設定を 1 つにまとめ、タブで切り替えるメインウィンドウ。
struct MainWindowView: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            DashboardView()
                .tabItem { Label(MainTab.dashboard.title, systemImage: MainTab.dashboard.systemImage) }
                .tag(MainTab.dashboard)
            ProjectManagementView()
                .tabItem { Label(MainTab.projects.title, systemImage: MainTab.projects.systemImage) }
                .tag(MainTab.projects)
            SettingsView()
                .tabItem { Label(MainTab.settings.title, systemImage: MainTab.settings.systemImage) }
                .tag(MainTab.settings)
        }
        .frame(minWidth: 680, minHeight: 520)
    }
}
