import AppKit

/// アプリから前面に出す単発パネル（作業内容入力・自動停止通知など）の生成と配置。
@MainActor
enum FloatingPanel {
    static func make(
        size: NSSize, title: String,
        level: NSWindow.Level = .floating,
        styleMask: NSWindow.StyleMask = [.titled]
    ) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask, backing: .buffered, defer: false
        )
        panel.title = title
        panel.level = level
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        center(panel)
        return panel
    }

    /// マウスのあるスクリーンの中央に配置する。
    static func center(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first {
            NSMouseInRect(mouse, $0.frame, false)
        } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        let panelSize = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.midY - panelSize.height / 2
        ))
    }

    static func present(_ panel: NSPanel) {
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
