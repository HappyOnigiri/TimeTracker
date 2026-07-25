import Foundation
import Testing
@testable import TimeTracker

struct TimeInputCommitTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(hour: Int, minute: Int, second: Int = 0, day: Int = 20) throws -> Date {
        try #require(
            calendar.date(
                from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute, second: second)
            )
        )
    }

    // MARK: - 入力中の反映

    @Test("入力途中の1桁でも Date に反映される")
    func evaluateSingleDigit() throws {
        let current = try date(hour: 9, minute: 0)
        let expected = try date(hour: 1, minute: 0)
        let outcome = TimeInputCommit.evaluate(
            text: "1", current: current, referenceDate: current, calendar: calendar
        )
        #expect(outcome == .updated(expected))
    }

    @Test("4桁入力が Date に反映される")
    func evaluateFourDigits() throws {
        let current = try date(hour: 9, minute: 0)
        let expected = try date(hour: 18, minute: 30)
        let outcome = TimeInputCommit.evaluate(
            text: "1830", current: current, referenceDate: current, calendar: calendar
        )
        #expect(outcome == .updated(expected))
    }

    @Test("コロン付き入力が Date に反映される")
    func evaluateWithColon() throws {
        let current = try date(hour: 9, minute: 0)
        let expected = try date(hour: 18, minute: 30)
        let outcome = TimeInputCommit.evaluate(
            text: "18:30", current: current, referenceDate: current, calendar: calendar
        )
        #expect(outcome == .updated(expected))
    }

    @Test("referenceDate の年月日を保ったまま時刻だけ更新する")
    func evaluateKeepsReferenceDay() throws {
        let current = try date(hour: 9, minute: 0, day: 20)
        let reference = try date(hour: 0, minute: 0, day: 25)
        let expected = try date(hour: 9, minute: 0, day: 25)
        let outcome = TimeInputCommit.evaluate(
            text: "9:00", current: current, referenceDate: reference, calendar: calendar
        )
        #expect(outcome == .updated(expected))
    }

    // MARK: - 変更なし

    @Test("同じ時刻の入力は unchanged")
    func evaluateUnchanged() throws {
        let current = try date(hour: 9, minute: 0)
        let outcome = TimeInputCommit.evaluate(
            text: "9:00", current: current, referenceDate: current, calendar: calendar
        )
        #expect(outcome == .unchanged)
    }

    @Test("秒だけ違う場合は unchanged（表示同期で Date を書き換えない）")
    func evaluateIgnoresSeconds() throws {
        let current = try date(hour: 9, minute: 0, second: 45)
        let outcome = TimeInputCommit.evaluate(
            text: "9:00", current: current, referenceDate: current, calendar: calendar
        )
        #expect(outcome == .unchanged)
    }

    // MARK: - 不正入力

    @Test("コロンで終わる入力途中は invalid")
    func evaluateTrailingColon() throws {
        let current = try date(hour: 9, minute: 0)
        let outcome = TimeInputCommit.evaluate(
            text: "18:", current: current, referenceDate: current, calendar: calendar
        )
        #expect(outcome == .invalid)
    }

    @Test("空文字は invalid")
    func evaluateEmpty() throws {
        let current = try date(hour: 9, minute: 0)
        let outcome = TimeInputCommit.evaluate(
            text: "", current: current, referenceDate: current, calendar: calendar
        )
        #expect(outcome == .invalid)
    }

    @Test("範囲外の時刻は invalid")
    func evaluateOutOfRange() throws {
        let current = try date(hour: 9, minute: 0)
        let outcome = TimeInputCommit.evaluate(
            text: "2560", current: current, referenceDate: current, calendar: calendar
        )
        #expect(outcome == .invalid)
    }
}
