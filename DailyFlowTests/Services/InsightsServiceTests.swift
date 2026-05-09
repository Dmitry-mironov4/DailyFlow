import Testing
import Foundation
import SwiftData
@testable import DailyFlow

extension DailyFlowTests {
@Suite("InsightsService", .serialized) @MainActor
struct InsightsServiceTests {

    // MARK: — Helpers

    /// Фиксированная "сегодняшняя" дата для всех тестов: 2026-05-10 00:00 UTC.
    /// Гарантирует детерминированность независимо от часов прогона.
    static let today: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 10
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar.current.date(from: components)!
    }()

    /// Возвращает startOfDay для today + offsetDays (offsetDays может быть отрицательным).
    static func day(_ offsetDays: Int) -> Date {
        let raw = Calendar.current.date(byAdding: .day, value: offsetDays, to: today)!
        return Calendar.current.startOfDay(for: raw)
    }
}
}
