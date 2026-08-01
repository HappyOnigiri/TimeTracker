import SwiftData
import SwiftUI

/// メニューバー常駐のタイムトラッキングアプリのエントリポイント。
@main
struct TimeTrackerApp: App {
    @AppStorage(AppSettingsKey.displayLanguage)
    private var displayLanguage = AppSettingsDefault.displayLanguage
    @State private var engine = TimerEngine()
    @State private var activeTimeTracker = ActiveTimeTracker()
    @State private var navigation = AppNavigation()
    private let container: ModelContainer

    init() {
        if ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil,
           let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            exit(0)
        }

        do {
            container = try ModelContainer(for: Project.self, TimeLog.self, ActiveSession.self)
#if SCREENSHOT_BUILD
            try ScreenshotSampleData.replaceAll(
                in: container.mainContext,
                language: AppSettings().displayLanguage.resolved()
            )
#endif
        } catch {
            fatalError("ModelContainer の生成に失敗しました: \(error)")
        }
    }

    var body: some Scene {
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
