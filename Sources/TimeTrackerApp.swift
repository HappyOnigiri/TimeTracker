import SwiftData
import SwiftUI

/// メニューバー常駐のタイムトラッキングアプリのエントリポイント。
@main
struct TimeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate
    @AppStorage(AppSettingsKey.displayLanguage)
    private var displayLanguage = AppSettingsDefault.displayLanguage
    @State private var engine = TimerEngine()
    @State private var activeTimeTracker = ActiveTimeTracker()
    @State private var navigation = AppNavigation()
    private let container: ModelContainer

    init() {
        // テストホストとして起動されたか。
        //
        // `xcodebuild test` はアプリ本体をプロセス起動してテストバンドルを注入するため、
        // 通常起動と同じ初期化が走ってしまう。実アプリと同じサンドボックスコンテナで動く以上、
        // 既定のストアを開けば本番データを壊す（起動時の孤児ログ整理が計測中ログを潰す）。
        // ストアは in-memory にする。
        let isTestHost = ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil

        if !isTestHost,
           let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            exit(0)
        }

        do {
            container = try ModelContainer(
                for: Project.self, TimeLog.self, WorkNote.self, ActiveSession.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: isTestHost)
            )
#if SCREENSHOT_BUILD
            try ScreenshotSampleData.replaceAll(
                in: container.mainContext,
                language: AppSettings().displayLanguage.resolved()
            )
#endif
            try WorkNoteCatalog.bootstrap(in: container.mainContext)
        } catch {
            fatalError("ModelContainer の生成に失敗しました: \(error)")
        }
    }

    var body: some Scene {
        // `isInserted:` は付けない。挿入状態をバインディングで管理する形にすると
        // MenuBarExtra が常駐シーンとして扱われず、ポップオーバーやメインウィンドウを
        // 閉じた時点でアプリが終了してメニューバーから消える。
        MenuBarExtra {
            MenuBarContentView()
                .environment(engine)
                .environment(navigation)
                .environment(\.locale, displayLanguage.locale)
                .modelContainer(container)
        } label: {
            Image(nsImage: MenuBarIcon.image(forColorHexes: engine.runningColorHexes))
                .accessibilityLabel(
                    engine.isAnyRunning
                        ? L10n.string("測定中", locale: displayLanguage.locale)
                        : L10n.string("全停止中", locale: displayLanguage.locale)
                )
                .onAppear {
                    engine.configure(context: container.mainContext)
                    activeTimeTracker.configure(context: container.mainContext)
                }
        }
        .menuBarExtraStyle(.window)

        Window("TimeTracker", id: WindowID.main) {
            MainWindowView()
                .environment(engine)
                .environment(navigation)
                .environment(\.locale, displayLanguage.locale)
                .modelContainer(container)
        }
        .defaultSize(width: 720, height: 560)
    }
}
