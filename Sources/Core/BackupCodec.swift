import Foundation

/// バックアップの読み書きで発生する異常。
enum BackupError: LocalizedError, Equatable {
    /// 現行より新しいフォーマット版数のファイルを読もうとした。
    case unsupportedFormatVersion(Int)
    /// JSON として壊れている、または必要な項目が欠けている。
    case malformedFile

    private var localizationKey: String.LocalizationValue {
        switch self {
        case .unsupportedFormatVersion:
            "このバックアップは新しいバージョンのアプリで作成されています。アプリを更新してください。"
        case .malformedFile:
            "バックアップファイルを読み取れませんでした。"
        }
    }

    var errorDescription: String? {
        localizedDescription(locale: .current)
    }

    func localizedDescription(locale: Locale) -> String {
        L10n.string(localizationKey, locale: locale)
    }
}

/// `BackupSnapshot` と JSON データを相互変換する。Foundation だけに依存する純粋なロジック。
enum BackupCodec {
    /// 決定的な JSON を出力する。
    ///
    /// 将来の git バックアップでは差分が意味を持つため、同じスナップショットからは
    /// 常に同じバイト列が出ることを前提にする（キー順の固定と整形の固定）。
    /// 日付は ISO 8601（秒精度）で書くため、秒未満は保存されない。
    static func encode(_ snapshot: BackupSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    static func decode(_ data: Data) throws -> BackupSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 版数だけを先に読む。項目構成が変わった新形式でも「壊れている」ではなく
        // 「新しすぎる」と伝えられるようにする。
        guard let probe = try? decoder.decode(FormatVersionProbe.self, from: data) else {
            throw BackupError.malformedFile
        }
        guard probe.formatVersion <= BackupSnapshot.currentFormatVersion else {
            throw BackupError.unsupportedFormatVersion(probe.formatVersion)
        }
        do {
            return try decoder.decode(BackupSnapshot.self, from: data)
        } catch {
            throw BackupError.malformedFile
        }
    }

    private struct FormatVersionProbe: Decodable {
        let formatVersion: Int
    }
}
