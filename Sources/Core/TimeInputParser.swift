import Foundation

enum TimeInputParser {
    struct ParsedTime {
        let hour: Int
        let minute: Int
    }

    static func parse(_ input: String) -> ParsedTime? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let hour: Int
        let minute: Int

        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  let parsedHour = Int(parts[0]),
                  let parsedMinute = Int(parts[1]) else { return nil }
            hour = parsedHour
            minute = parsedMinute
        } else {
            guard let number = Int(trimmed), trimmed.allSatisfy(\.isASCII) && trimmed.allSatisfy(\.isNumber) else {
                return nil
            }
            switch trimmed.count {
            case 1, 2:
                hour = number
                minute = 0
            case 3:
                hour = number / 100
                minute = number % 100
            case 4:
                hour = number / 100
                minute = number % 100
            default:
                return nil
            }
        }

        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return ParsedTime(hour: hour, minute: minute)
    }

    static func formatDisplay(_ time: ParsedTime) -> String {
        String(format: "%d:%02d", time.hour, time.minute)
    }

    static func applyToDate(_ time: ParsedTime, referenceDate: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: referenceDate) ?? referenceDate
    }
}
