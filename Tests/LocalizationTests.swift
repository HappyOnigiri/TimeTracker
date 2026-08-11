import Foundation
import Testing
@testable import TimeTracker

struct LocalizationTests {
    @Test("対応言語と未対応言語を解決する")
    func resolvesPreferredLanguages() {
        #expect(AppLanguage.system.resolved(preferredLanguages: ["ja-JP"]) == .japanese)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["en-US"]) == .english)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN"]) == .simplifiedChinese)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["zh-Hant-TW"]) == .simplifiedChinese)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]) == .english)
        #expect(AppLanguage.japanese.resolved(preferredLanguages: ["en-US"]) == .japanese)
    }

    @Test("保存済みの不正な言語値は自動設定へ戻す")
    func invalidStoredLanguageFallsBack() {
        let suiteName = "LocalizationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("unsupported", forKey: AppSettingsKey.displayLanguage)
        #expect(AppSettings(defaults: defaults).displayLanguage == .system)
    }

    @Test("同じキーを英語、日本語、中国語で取得できる")
    func localizesStringCatalogEntries() {
        #expect(L10n.string("保存", locale: Locale(identifier: "en")) == "Save")
        #expect(L10n.string("保存", locale: Locale(identifier: "ja")) == "保存")
        #expect(L10n.string("保存", locale: Locale(identifier: "zh-Hans")) == "保存")
    }

    @Test("作業内容管理と同名統合の主要文言を3言語で取得できる")
    func localizesWorkNoteManagement() {
        let expectations: [(key: String.LocalizationValue, values: [String: String])] = [
            (
                "作業内容を管理",
                ["en": "Manage Work Notes", "ja": "作業内容を管理", "zh-Hans": "管理工作内容"]
            ),
            (
                "紐づくプロジェクト",
                ["en": "Linked Projects", "ja": "紐づくプロジェクト", "zh-Hans": "关联项目"]
            ),
            ("すべて表示", ["en": "Show All", "ja": "すべて表示", "zh-Hans": "显示全部"]),
            (
                "管理する作業内容",
                ["en": "Work Note to Manage", "ja": "管理する作業内容", "zh-Hans": "要管理的工作内容"]
            ),
            (
                "同名の作業内容へ統合しますか？",
                [
                    "en": "Merge with the existing work note?",
                    "ja": "同名の作業内容へ統合しますか？",
                    "zh-Hans": "要合并到同名工作内容吗？"
                ]
            ),
            (
                "worknote.merge.confirmation",
                [
                    "en": "Merge “%1$@” into the existing “%2$@”. %3$d records will be updated, "
                        + "and linked projects will be combined. This action cannot be undone.",
                    "ja": "「%1$@」を既存の「%2$@」へ統合します。%3$d 件の記録が置き換わり、"
                        + "紐づくプロジェクトは和集合になります。"
                        + "この操作は取り消せません。",
                    "zh-Hans": "将“%1$@”合并到现有的“%2$@”。"
                        + "将更新 %3$d 条记录，并合并关联项目。此操作无法撤销。"
                ]
            )
        ]
        for expectation in expectations {
            for (identifier, value) in expectation.values {
                #expect(L10n.string(expectation.key, locale: Locale(identifier: identifier)) == value)
            }
        }
    }

    @Test("言語名は現在の表示言語によらず自称表記になる")
    func displaysLanguageAutonyms() {
        for identifier in ["en", "ja", "zh-Hans"] {
            let locale = Locale(identifier: identifier)
            #expect(AppLanguage.english.displayName(locale: locale) == "English")
            #expect(AppLanguage.japanese.displayName(locale: locale) == "日本語")
            #expect(AppLanguage.simplifiedChinese.displayName(locale: locale) == "简体中文")
        }
    }

    @Test("経過時間を英語と日本語で整形する")
    func formatsLocalizedDurations() {
        #expect(DurationFormatter.string(from: 4_980, locale: Locale(identifier: "en")) == "1 hr 23 min")
        #expect(DurationFormatter.string(from: 4_980, locale: Locale(identifier: "ja")) == "1時間23分")
        #expect(DurationFormatter.string(from: 4_980, locale: Locale(identifier: "zh-Hans")) == "1小时23分钟")
    }

    @Test("月ラベルは選択言語の語順になる")
    func formatsLocalizedMonthLabels() {
        let date = TestSupport.date(2026, 7, 1)
        #expect(RecordsView.monthLabel(for: date, locale: Locale(identifier: "en_US")) == "July 2026")
        #expect(RecordsView.monthLabel(for: date, locale: Locale(identifier: "ja_JP")) == "2026年7月")
        #expect(RecordsView.monthLabel(for: date, locale: Locale(identifier: "zh_Hans_CN")) == "2026年7月")
    }
}
