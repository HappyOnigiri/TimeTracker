import Foundation

/// AppStorage / UserDefaults で永続化する設定のキーと既定値。
///
/// SwiftUI 側は `@AppStorage(AppSettingsKey.xxx)` で参照し、
/// 非 View 層（TimerEngine 等）は `AppSettings` 経由で UserDefaults を読む。
enum AppSettingsKey {
    static let idleDetectionEnabled = "idleDetectionEnabled"
    static let idleThresholdMinutes = "idleThresholdMinutes"
    static let allowConcurrentTracking = "allowConcurrentTracking"
}

enum AppSettingsDefault {
    static let idleDetectionEnabled = true
    static let idleThresholdMinutes = 5
    static let allowConcurrentTracking = true
}

/// 非 View 層から設定値を読むためのアクセサ。
struct AppSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            AppSettingsKey.idleDetectionEnabled: AppSettingsDefault.idleDetectionEnabled,
            AppSettingsKey.idleThresholdMinutes: AppSettingsDefault.idleThresholdMinutes,
            AppSettingsKey.allowConcurrentTracking: AppSettingsDefault.allowConcurrentTracking
        ])
    }

    /// 離席判定（アイドル自動停止）が有効か。
    var idleDetectionEnabled: Bool {
        defaults.bool(forKey: AppSettingsKey.idleDetectionEnabled)
    }

    /// アイドル判定までの分数。
    var idleThresholdMinutes: Int {
        max(0, defaults.integer(forKey: AppSettingsKey.idleThresholdMinutes))
    }

    /// 0 分はデバッグ用：タイマー開始後 5 秒間入力がなければ離席と判定する。
    var idleThresholdSeconds: TimeInterval {
        idleThresholdMinutes == 0 ? 5 : TimeInterval(idleThresholdMinutes) * 60
    }

    var allowConcurrentTracking: Bool {
        defaults.bool(forKey: AppSettingsKey.allowConcurrentTracking)
    }
}
