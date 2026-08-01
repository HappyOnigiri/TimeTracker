import Foundation

/// アプリ内で選択できる表示言語。
///
/// rawValue は UserDefaults に永続化するため、表示名とは独立した安定値にする。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case japanese = "ja"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    /// SwiftUI と Foundation の表示書式に適用する locale。
    var locale: Locale {
        switch self {
        case .system:
            resolved().locale
        case .english:
            Locale(identifier: "en")
        case .japanese:
            Locale(identifier: "ja")
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        }
    }

    /// 言語 Picker に表示する、現在の UI 言語でローカライズされた名前。
    func displayName(locale: Locale) -> String {
        switch self {
        case .system:
            L10n.string("自動（システム設定）", locale: locale)
        case .english:
            L10n.string("英語", locale: locale)
        case .japanese:
            L10n.string("日本語", locale: locale)
        case .simplifiedChinese:
            L10n.string("中国語", locale: locale)
        }
    }

    /// Sample データなど、対応言語を明示的に 1 つ選ぶ必要がある箇所で使う。
    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        guard let preferred = preferredLanguages.first else { return .english }
        if preferred.hasPrefix("ja") { return .japanese }
        if preferred.hasPrefix("zh") { return .simplifiedChinese }
        return .english
    }
}

/// SwiftUI の LocalizedStringKey が使えない AppKit・Core 層向けの翻訳アクセサ。
enum L10n {
    static func string(_ key: String.LocalizationValue, locale: Locale) -> String {
        String(
            localized: key,
            table: "Localizable",
            bundle: localizedBundle(for: locale),
            locale: locale
        )
    }

    private static func localizedBundle(for locale: Locale) -> Bundle {
        let language = locale.language.languageCode?.identifier ?? "en"
        let resource = language == "zh" ? AppLanguage.simplifiedChinese.rawValue : language
        guard let path = Bundle.main.path(forResource: resource, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
