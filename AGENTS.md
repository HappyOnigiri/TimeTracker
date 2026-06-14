# TimeTracker アーキテクチャ
macOS メニューバー常駐タイムトラッカー。SwiftUI, SwiftData, SwiftCharts。App Sandbox 有効。ビルド: XcodeGen。

## エントリ/設定
- [TimeTrackerApp.swift](file:///Users/un/dev/TimeTracker/Sources/TimeTrackerApp.swift): エントリ, MenuBarExtra, SwiftDataセットアップ
- [project.yml](file:///Users/un/dev/TimeTracker/project.yml): XcodeGen設定, Sandbox権限
- [README.md](file:///Users/un/dev/TimeTracker/README.md): 仕様, ビルド手順

## Models
- [Project.swift](file:///Users/un/dev/TimeTracker/Sources/Models/Project.swift): プロジェクト(SwiftData)
- [TimeLog.swift](file:///Users/un/dev/TimeTracker/Sources/Models/TimeLog.swift): 記録ログ(SwiftData)

## Core
- [TimerEngine.swift](file:///Users/un/dev/TimeTracker/Sources/Core/TimerEngine.swift): タイマー状態管理
- [IdleDetector.swift](file:///Users/un/dev/TimeTracker/Sources/Core/IdleDetector.swift): アイドル検知(CGEventSource, 権限不要)
- [ReportAggregator.swift](file:///Users/un/dev/TimeTracker/Sources/Core/ReportAggregator.swift): データ集計
- [CSVExporter.swift](file:///Users/un/dev/TimeTracker/Sources/Core/CSVExporter.swift), [CSVExportService.swift](file:///Users/un/dev/TimeTracker/Sources/Core/CSVExportService.swift): CSV出力, NSSavePanel
- [AppSettings.swift](file:///Users/un/dev/TimeTracker/Sources/Core/AppSettings.swift): 設定管理
- [AppNavigation.swift](file:///Users/un/dev/TimeTracker/Sources/Core/AppNavigation.swift): 画面遷移/ウィンドウ制御
- [LoginItemService.swift](file:///Users/un/dev/TimeTracker/Sources/Core/LoginItemService.swift): ログイン自動起動設定
- [DurationFormatter.swift](file:///Users/un/dev/TimeTracker/Sources/Core/DurationFormatter.swift), [Color+Hex.swift](file:///Users/un/dev/TimeTracker/Sources/Core/Color+Hex.swift): ユーティリティ

## Views
- [MenuBarContentView.swift](file:///Users/un/dev/TimeTracker/Sources/Views/MenuBarContentView.swift): メイン画面(ポップオーバー)
- [MenuBarIcon.swift](file:///Users/un/dev/TimeTracker/Sources/Views/MenuBarIcon.swift): アイコン/アニメーション
- [DashboardView.swift](file:///Users/un/dev/TimeTracker/Sources/Views/DashboardView.swift): グラフ(Swift Charts)
- [ProjectManagementView.swift](file:///Users/un/dev/TimeTracker/Sources/Views/ProjectManagementView.swift): プロジェクトCRUD
- [SettingsView.swift](file:///Users/un/dev/TimeTracker/Sources/Views/SettingsView.swift): 設定画面
- [MainWindowView.swift](file:///Users/un/dev/TimeTracker/Sources/Views/MainWindowView.swift): 独立ウィンドウ
