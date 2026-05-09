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

    // MARK: — tasksRate

    @Test func tasksRate_returnsNil_whenNoTasksInWindow() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        #expect(InsightsService.tasksRate(today: Self.today, in: ctx) == nil)
    }

    @Test func tasksRate_excludesTasksOutsideWindow() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // Задача за пределами окна (today − 7) — не учитывается.
        ctx.insert(DailyTask(title: "Out of window", date: Self.day(-7)))
        // Задача в окне (today) — учитывается.
        ctx.insert(DailyTask(title: "In window", date: Self.today))
        try ctx.save()
        // 1 задача в окне, не закрыта → 0.0.
        #expect(InsightsService.tasksRate(today: Self.today, in: ctx) == 0.0)
    }

    @Test func tasksRate_returnsCorrectFraction() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        for i in 0..<5 {
            let task = DailyTask(title: "T\(i)", date: Self.day(-i))
            if i < 3 {
                task.isCompleted = true
                task.completedAt = .now
            }
            ctx.insert(task)
        }
        try ctx.save()
        let rate = InsightsService.tasksRate(today: Self.today, in: ctx)
        #expect(abs((rate ?? -1) - 0.6) < 0.0001)
    }

    @Test func tasksRate_ignoresFutureTasks() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // Задача "на завтра" не входит в окно [today−6 … today].
        ctx.insert(DailyTask(title: "Tomorrow", date: Self.day(1)))
        try ctx.save()
        #expect(InsightsService.tasksRate(today: Self.today, in: ctx) == nil)
    }
}
}
