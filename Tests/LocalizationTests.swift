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
