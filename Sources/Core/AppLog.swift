import Foundation
import OSLog

/// アプリ共通のロガー。
///
/// 保存失敗などの異常を握り潰すと計測データの欠落に気付けないため、
/// 必ずここを通してログに残す。
enum AppLog {
    static let persistence = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "TimeTracker",
        category: "persistence"
    )
}
