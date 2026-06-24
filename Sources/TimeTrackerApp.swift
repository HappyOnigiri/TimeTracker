import SwiftData
import SwiftUI

enum WindowID {
    static let main = "main"
}

/// メニューバー常駐のタイムトラッキングアプリのエントリポイント。
@main
struct TimeTrackerApp: App {
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
        } catch {
            fatalError("ModelContainer の生成に失敗しました: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(engine)
                .environment(navigation)
                .modelContainer(container)
        } label: {
            Image(nsImage: MenuBarIcon.image(forColorHexes: engine.runningColorHexes))
                .accessibilityLabel(engine.isAnyRunning ? "測定中" : "全停止中")
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
                .modelContainer(container)
        }
        .defaultSize(width: 720, height: 560)
    }
}
