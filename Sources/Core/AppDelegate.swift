import AppKit

/// ウィンドウをすべて閉じてもプロセスを終了させないためのアプリデリゲート。
///
/// `Window` シーンと `MenuBarExtra` を併用すると、最後の可視ウィンドウ（メインウィンドウや
/// メニューバーのポップオーバー）が閉じた時点で AppKit がアプリを終了させ、
/// メニューバーアイコンごと常駐が消える。終了はメニューの「TimeTracker を終了」など
/// 明示的な操作だけに限定する。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
