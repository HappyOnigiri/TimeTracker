import CoreGraphics
import Foundation

/// システムの最終入力からの経過秒数を取得するユーティリティ。
///
/// `CGEventSource.secondsSinceLastEventType` は HID のアイドル秒数を読むだけで、
/// イベントタップと異なりアクセシビリティ（入力監視）権限を必要としない。
/// App Sandbox 内でも権限ダイアログなしに動作する。
enum IdleDetector {
    /// あらゆる入力（マウス/キーボード）からの経過秒数。取得不能時は 0 を返す。
    static func secondsSinceLastInput() -> TimeInterval {
        // kCGAnyInputEventType（= 0xFFFFFFFF）であらゆる入力イベントを対象にする。
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
