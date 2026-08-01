import Foundation

/// AppStorage / UserDefaults で永続化する設定のキーと既定値。
///
/// SwiftUI 側は `@AppStorage(AppSettingsKey.xxx)` で参照し、
/// 非 View 層（TimerEngine 等）は `AppSettings` 経由で UserDefaults を読む。
enum AppSettingsKey {
    static let idleDetectionEnabled = "idleDetectionEnabled"
    static let idleThresholdMinutes = "idleThresholdMinutes"
    static let idleAlertEnabled = "idleAlertEnabled"
    static let allowConcurrentTracking = "allowConcurrentTracking"
    static let timelineSnapMinutes = "timelineSnapMinutes"
    static let promptForWorkNoteOnStop = "promptForWorkNoteOnStop"
    static let dimBlocksWithoutNotes = "dimBlocksWithoutNotes"
    static let displayLanguage = "displayLanguage"
    static let lastHeartbeat = "lastHeartbeat"
}

enum AppSettingsDefault {
    static let idleDetectionEnabled = true
    static let idleThresholdMinutes = 5
    static let idleAlertEnabled = true
    static let allowConcurrentTracking = true
    static let timelineSnapMinutes = 5
    static let promptForWorkNoteOnStop = true
    static let dimBlocksWithoutNotes = true
    static let displayLanguage = AppLanguage.system
}

/// 非 View 層から設定値を読むためのアクセサ。
struct AppSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            AppSettingsKey.idleDetectionEnabled: AppSettingsDefault.idleDetectionEnabled,
            AppSettingsKey.idleThresholdMinutes: AppSettingsDefault.idleThresholdMinutes,
            AppSettingsKey.idleAlertEnabled: AppSettingsDefault.idleAlertEnabled,
            AppSettingsKey.allowConcurrentTracking: AppSettingsDefault.allowConcurrentTracking,
            AppSettingsKey.timelineSnapMinutes: AppSettingsDefault.timelineSnapMinutes,
            AppSettingsKey.promptForWorkNoteOnStop: AppSettingsDefault.promptForWorkNoteOnStop,
            AppSettingsKey.dimBlocksWithoutNotes: AppSettingsDefault.dimBlocksWithoutNotes,
            AppSettingsKey.displayLanguage: AppSettingsDefault.displayLanguage.rawValue
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

    var idleAlertEnabled: Bool {
        defaults.bool(forKey: AppSettingsKey.idleAlertEnabled)
    }

    var allowConcurrentTracking: Bool {
        defaults.bool(forKey: AppSettingsKey.allowConcurrentTracking)
    }

    var timelineSnapMinutes: Int {
        let value = defaults.integer(forKey: AppSettingsKey.timelineSnapMinutes)
        return [5, 10, 15, 30].contains(value) ? value : AppSettingsDefault.timelineSnapMinutes
    }

    var promptForWorkNoteOnStop: Bool {
        defaults.bool(forKey: AppSettingsKey.promptForWorkNoteOnStop)
    }

    var dimBlocksWithoutNotes: Bool {
        defaults.bool(forKey: AppSettingsKey.dimBlocksWithoutNotes)
    }

    /// 計測中のアプリが最後に生存を記録した時刻。未記録なら nil。
    ///
    /// クラッシュや強制終了で終了処理が走らなかったとき、次回起動時に
    /// 「どこまで計測できていたか」を復元するために使う。
    var lastHeartbeat: Date? {
        let value = defaults.double(forKey: AppSettingsKey.lastHeartbeat)
        return value > 0 ? Date(timeIntervalSinceReferenceDate: value) : nil
    }

    func recordHeartbeat(_ date: Date) {
        defaults.set(date.timeIntervalSinceReferenceDate, forKey: AppSettingsKey.lastHeartbeat)
    }

    var displayLanguage: AppLanguage {
        guard let rawValue = defaults.string(forKey: AppSettingsKey.displayLanguage) else {
            return AppSettingsDefault.displayLanguage
        }
        return AppLanguage(rawValue: rawValue) ?? AppSettingsDefault.displayLanguage
    }
}
