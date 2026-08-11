import AppKit
import SwiftUI

// MARK: - パネル表示

extension TimerEngine {
    func showRetroactiveStartPanel(for project: Project) {
        guard ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil else { return }
        retroactiveStartPanel?.close()
        let locale = settings.displayLanguage.locale
        let panel = FloatingPanel.make(
            size: NSSize(width: 380, height: 300),
            title: L10n.string("開始時刻を指定", locale: locale)
        )
        let view = RetroactiveStartView(
            project: project, engine: self,
            onDismiss: { [weak self] in self?.dismissRetroactiveStartPanel() }
        )
        panel.contentView = NSHostingView(rootView: view.environment(\.locale, locale))
        retroactiveStartPanel = panel
        FloatingPanel.present(panel)
    }

    func dismissRetroactiveStartPanel() {
        retroactiveStartPanel?.close()
        retroactiveStartPanel = nil
    }

    func showWorkNotePrompt() {
        guard ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil else { return }
        workNotePanel?.close()
        guard let context else { return }
        let locale = settings.displayLanguage.locale
        let panel = FloatingPanel.make(
            size: NSSize(width: 480, height: 350),
            title: L10n.string("作業内容を記録", locale: locale),
            styleMask: [.titled, .resizable]
        )
        let view = WorkNotePromptView(engine: self)
            .environment(\.locale, locale)
            .modelContainer(context.container)
        panel.contentView = NSHostingView(rootView: view)
        workNotePanel = panel
        FloatingPanel.present(panel)
    }

    func showIdleStopAlert() {
        guard ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil else { return }
        idleAlertPanel?.close()
        guard let context else { return }
        let locale = settings.displayLanguage.locale
        let panelHeight: CGFloat = settings.promptForWorkNoteOnStop ? 420 : 280
        let panel = FloatingPanel.make(
            size: NSSize(width: 480, height: panelHeight),
            title: L10n.string("タイマー自動停止", locale: locale), level: .screenSaver,
            styleMask: [.titled, .resizable]
        )
        let view = IdleStopAlertView(engine: self)
            .environment(\.locale, locale)
            .modelContainer(context.container)
        panel.contentView = NSHostingView(rootView: view)
        idleAlertPanel = panel
        FloatingPanel.present(panel)
    }
}
