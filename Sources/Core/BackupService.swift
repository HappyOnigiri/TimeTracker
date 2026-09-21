import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// バックアップデータの保存先。nil を返した場合はユーザーが取り消したことを表す。
///
/// 将来の git バックアップは、この protocol の別実装を渡すだけで済ませる。
@MainActor
protocol BackupDestination {
    func write(_ data: Data, suggestedName: String) throws -> URL?
}

/// バックアップデータの読み込み元。nil を返した場合はユーザーが取り消したことを表す。
@MainActor
protocol BackupSource {
    func read() throws -> Data?
}

/// NSSavePanel でユーザーが選んだ場所へ書き出す（App Sandbox 準拠）。
@MainActor
struct UserSelectedFileBackupDestination: BackupDestination {
    // 引数の既定値として生成できるよう、初期化は MainActor から切り離す
    // （自動合成の初期化子は MainActor 隔離になり、既定値の式から呼べない）。
    // swiftlint:disable:next unneeded_synthesized_initializer
    nonisolated init() {}

    func write(_ data: Data, suggestedName: String) throws -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try data.write(to: url, options: .atomic)
        return url
    }
}

/// NSOpenPanel でユーザーが選んだファイルを読む（App Sandbox 準拠）。
@MainActor
struct UserSelectedFileBackupSource: BackupSource {
    // 引数の既定値として生成できるよう、初期化は MainActor から切り離す
    // （自動合成の初期化子は MainActor 隔離になり、既定値の式から呼べない）。
    // swiftlint:disable:next unneeded_synthesized_initializer
    nonisolated init() {}

    func read() throws -> Data? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return try Data(contentsOf: url)
    }
}

/// バックアップの書き出しと復元を、保存先の選択と結果の受け渡しに限って担う層。
///
/// 検証可能なロジックは `BackupSnapshotBuilder` / `BackupCodec` / `BackupRestorer` に置き、
/// ここではパネル操作と結果の値詰め替えだけを行う。
@MainActor
enum BackupService {
    enum BackupResult: Equatable {
        case saved(URL)
        case cancelled
        case failed(String)
    }

    enum RestoreResult: Equatable {
        case restored
        case cancelled
        case failed(String)
    }

    /// 現在のデータをバックアップとして書き出す。
    static func backup(
        from context: ModelContext,
        to destination: BackupDestination = UserSelectedFileBackupDestination(),
        now: Date = Date(),
        defaults: UserDefaults = .standard,
        locale: Locale = .current
    ) -> BackupResult {
        do {
            let snapshot = try BackupSnapshotBuilder.make(from: context, exportedAt: now, defaults: defaults)
            let data = try BackupCodec.encode(snapshot)
            guard let url = try destination.write(data, suggestedName: suggestedFileName(for: now)) else {
                return .cancelled
            }
            return .saved(url)
        } catch {
            return .failed(message(for: error, locale: locale))
        }
    }

    /// バックアップからデータと設定を全置換で復元する。
    ///
    /// `willReplace` はファイルの読み込みと解析に成功し、全置換を始める直前に 1 度だけ呼ぶ。
    /// 計測の停止（`TimerEngine.prepareForDataReplacement()` 等）はここで行う。
    /// ユーザーが選択を取り消した場合や、ファイルが読めなかった場合には呼ばれない。
    static func restore(
        into context: ModelContext,
        from source: BackupSource = UserSelectedFileBackupSource(),
        defaults: UserDefaults = .standard,
        locale: Locale = .current,
        willReplace: () -> Void = {}
    ) -> RestoreResult {
        do {
            guard let data = try source.read() else { return .cancelled }
            let snapshot = try BackupCodec.decode(data)
            willReplace()
            try BackupRestorer.restore(snapshot, into: context, defaults: defaults)
            return .restored
        } catch {
            AppLog.persistence.error("バックアップの復元に失敗しました: \(error, privacy: .public)")
            return .failed(message(for: error, locale: locale))
        }
    }

    /// 既定のファイル名。日付は表示言語に依らず固定書式にする。
    static func suggestedFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "timetracker-backup-\(formatter.string(from: date)).json"
    }

    private static func message(for error: Error, locale: Locale) -> String {
        if let backupError = error as? BackupError {
            return backupError.localizedDescription(locale: locale)
        }
        return error.localizedDescription
    }
}
