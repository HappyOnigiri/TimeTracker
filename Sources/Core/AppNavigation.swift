import Observation
import SwiftUI

/// メインウィンドウのタブ。
enum MainTab: String, CaseIterable, Identifiable {
    case dashboard
    case projects
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "ダッシュボード"
        case .projects: "プロジェクト"
        case .settings: "設定"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "chart.bar"
        case .projects: "folder"
        case .settings: "gearshape"
        }
    }
}

/// メニューバーとメインウィンドウで共有するナビゲーション状態。
/// メニューから項目を選ぶと該当タブへ切り替えてウィンドウを開く。
@MainActor
@Observable
final class AppNavigation {
    var selectedTab: MainTab = .dashboard
}
