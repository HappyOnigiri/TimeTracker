import Foundation
import Testing
@testable import TimeTracker

struct TimeInputParserTests {
    // MARK: - parse: 正常系

    @Test("1桁の数字をhourとしてパース")
    func parseSingleDigit() {
        let result = TimeInputParser.parse("9")
        #expect(result?.hour == 9)
        #expect(result?.minute == 0)
    }

    @Test("2桁の数字をhourとしてパース")
    func parseTwoDigitsLeadingZero() {
        let result = TimeInputParser.parse("09")
        #expect(result?.hour == 9)
        #expect(result?.minute == 0)
    }

    @Test("2桁の数字(14)をhourとしてパース")
    func parseTwoDigits() {
        let result = TimeInputParser.parse("14")
        #expect(result?.hour == 14)
        #expect(result?.minute == 0)
    }

    @Test("3桁の数字を H:mm としてパース")
    func parseThreeDigits() {
        let result = TimeInputParser.parse("930")
        #expect(result?.hour == 9)
        #expect(result?.minute == 30)
    }

    @Test("3桁の数字(845)を H:mm としてパース")
    func parseThreeDigits845() {
        let result = TimeInputParser.parse("845")
        #expect(result?.hour == 8)
        #expect(result?.minute == 45)
    }

    @Test("4桁の数字を HH:mm としてパース")
    func parseFourDigitsLeadingZero() {
        let result = TimeInputParser.parse("0930")
        #expect(result?.hour == 9)
        #expect(result?.minute == 30)
    }

    @Test("4桁の数字(1045)を HH:mm としてパース")
    func parseFourDigits() {
        let result = TimeInputParser.parse("1045")
        #expect(result?.hour == 10)
        #expect(result?.minute == 45)
    }

    @Test("4桁の数字(2359)を HH:mm としてパース")
    func parseFourDigitsMax() {
        let result = TimeInputParser.parse("2359")
        #expect(result?.hour == 23)
        #expect(result?.minute == 59)
    }

    @Test("コロン付き(9:30)をパース")
    func parseWithColon() {
        let result = TimeInputParser.parse("9:30")
        #expect(result?.hour == 9)
        #expect(result?.minute == 30)
    }

    @Test("コロン付き(10:45)をパース")
    func parseWithColonTwoDigitHour() {
        let result = TimeInputParser.parse("10:45")
        #expect(result?.hour == 10)
        #expect(result?.minute == 45)
    }

    @Test("前後の空白をトリムしてパース")
    func parseWithWhitespace() {
        let result = TimeInputParser.parse("  930  ")
        #expect(result?.hour == 9)
        #expect(result?.minute == 30)
    }

    // MARK: - parse: 異常系

    @Test("hour=25は範囲外でnil")
    func parseInvalidHour() {
        #expect(TimeInputParser.parse("25") == nil)
    }

    @Test("2400は範囲外でnil")
    func parseInvalid2400() {
        #expect(TimeInputParser.parse("2400") == nil)
    }

    @Test("960はminute=60で範囲外でnil")
    func parseInvalidMinute() {
        #expect(TimeInputParser.parse("960") == nil)
    }

    @Test("空文字はnil")
    func parseEmpty() {
        #expect(TimeInputParser.parse("") == nil)
    }

    @Test("空白のみはnil")
    func parseWhitespaceOnly() {
        #expect(TimeInputParser.parse("  ") == nil)
    }

    @Test("非数値はnil")
    func parseNonNumeric() {
        #expect(TimeInputParser.parse("abc") == nil)
    }

    @Test("5桁以上はnil")
    func parseFiveDigits() {
        #expect(TimeInputParser.parse("12345") == nil)
    }

    @Test("コロンのみはnil")
    func parseColonOnly() {
        #expect(TimeInputParser.parse(":") == nil)
    }

    @Test("hour欠落のコロン付きはnil")
    func parseColonMissingHour() {
        #expect(TimeInputParser.parse(":30") == nil)
    }

    @Test("minute欠落のコロン付きはnil")
    func parseColonMissingMinute() {
        #expect(TimeInputParser.parse("10:") == nil)
    }

    @Test("1桁minuteのコロン付きをパース")
    func parseColonSingleDigitMinute() {
        let result = TimeInputParser.parse("9:5")
        #expect(result?.hour == 9)
        #expect(result?.minute == 5)
    }

    @Test("負数のコロン付きはnil")
    func parseColonNegativeHour() {
        #expect(TimeInputParser.parse("-1:30") == nil)
    }

    // MARK: - formatDisplay

    @Test("formatDisplayは H:mm 形式")
    func formatDisplay() {
        let result = TimeInputParser.formatDisplay(.init(hour: 9, minute: 5))
        #expect(result == "9:05")
    }

    @Test("formatDisplayは0時も正しく表示")
    func formatDisplayMidnight() {
        let result = TimeInputParser.formatDisplay(.init(hour: 0, minute: 0))
        #expect(result == "0:00")
    }

    // MARK: - applyToDate

    @Test("applyToDateはreferenceDateの年月日を保持する")
    func applyToDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let ref = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 8, minute: 0))
        )
        let time = TimeInputParser.ParsedTime(hour: 14, minute: 30)
        let result = TimeInputParser.applyToDate(time, referenceDate: ref, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)
        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 20)
        #expect(components.hour == 14)
        #expect(components.minute == 30)
    }
}
