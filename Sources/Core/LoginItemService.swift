import Foundation
import ServiceManagement

/// ログイン時の自動起動（ログイン項目）を管理するサービス。
///
/// `SMAppService.mainApp` はメインアプリ自身をログイン項目として登録する。
/// App Sandbox 内でも追加のエンタイトルメント・権限付与なしに動作する。
/// 登録状態はシステム側が保持するため、UI は UserDefaults ではなく
/// `isEnabled` で実際の状態を読む。
enum LoginItemService {
    /// 現在ログイン項目として登録されているか。
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 自動起動の有効/無効を切り替える。失敗時は throw する。
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            // 既に登録済みで再登録すると throw する場合があるため状態を確認する。
            guard SMAppService.mainApp.status != .enabled else { return }
            try SMAppService.mainApp.register()
        } else {
            guard SMAppService.mainApp.status == .enabled else { return }
            try SMAppService.mainApp.unregister()
        }
    }
}
