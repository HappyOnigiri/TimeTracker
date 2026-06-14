import Foundation
import Testing
@testable import TimeTracker

struct IdleDetectorTests {
    /// App Sandbox 内（テストホストはサンドボックス有効）で CGEventSource API が
    /// 権限なしに呼び出せ、非負の値を返すことを確認する。
    @Test("サンドボックス内でアイドル秒数を取得できる")
    func returnsNonNegativeIdleSeconds() {
        let seconds = IdleDetector.secondsSinceLastInput()
        #expect(seconds >= 0)
        #expect(seconds.isFinite)
    }
}
