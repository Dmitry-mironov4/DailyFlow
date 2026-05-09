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

    // MARK: — habitsRate

    @Test func habitsRate_returnsNil_whenNoHabits() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        #expect(InsightsService.habitsRate(today: Self.today, in: ctx) == nil)
    }

    @Test func habitsRate_returnsNil_whenAllHabitsCreatedAfterToday() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h = Habit(name: "Future", colorHex: "2DD4A0", sortOrder: 0)
        // createdAt вручную в будущее (тестовый трюк).
        h.createdAt = Self.day(1)
        ctx.insert(h)
        try ctx.save()
        #expect(InsightsService.habitsRate(today: Self.today, in: ctx) == nil)
    }

    @Test func habitsRate_returnsOne_whenAllHabitsDoneEveryDay() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h1 = Habit(name: "H1", colorHex: "2DD4A0", sortOrder: 0)
        let h2 = Habit(name: "H2", colorHex: "F0A23B", sortOrder: 1)
        h1.createdAt = Self.day(-30)
        h2.createdAt = Self.day(-30)
        ctx.insert(h1); ctx.insert(h2)
        for offset in -6...0 {
            ctx.insert(HabitLog(date: Self.day(offset), habit: h1))
            ctx.insert(HabitLog(date: Self.day(offset), habit: h2))
        }
        try ctx.save()
        let rate = InsightsService.habitsRate(today: Self.today, in: ctx)
        #expect(abs((rate ?? -1) - 1.0) < 0.0001)
    }

    @Test func habitsRate_perDayAveraging() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h1 = Habit(name: "H1", colorHex: "2DD4A0", sortOrder: 0)
        let h2 = Habit(name: "H2", colorHex: "F0A23B", sortOrder: 1)
        h1.createdAt = Self.day(-30)
        h2.createdAt = Self.day(-30)
        ctx.insert(h1); ctx.insert(h2)
        // День -6: оба сделаны → 2/2 = 1.0
        ctx.insert(HabitLog(date: Self.day(-6), habit: h1))
        ctx.insert(HabitLog(date: Self.day(-6), habit: h2))
        // День -5: только h1 → 1/2 = 0.5
        ctx.insert(HabitLog(date: Self.day(-5), habit: h1))
        // Дни -4 ... 0: оба не сделаны → 0/2 = 0.0
        try ctx.save()
        // Среднее: (1.0 + 0.5 + 0 + 0 + 0 + 0 + 0) / 7 = 1.5 / 7 ≈ 0.2143
        let rate = InsightsService.habitsRate(today: Self.today, in: ctx)
        #expect(abs((rate ?? -1) - (1.5 / 7.0)) < 0.0001)
    }

    @Test func habitsRate_excludesDaysBeforeFirstHabit() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // Привычка создана 2 дня назад. Дни -6...-3 не имеют активных привычек → skip.
        let h = Habit(name: "Newcomer", colorHex: "2DD4A0", sortOrder: 0)
        h.createdAt = Self.day(-2)
        ctx.insert(h)
        ctx.insert(HabitLog(date: Self.day(-2), habit: h))
        ctx.insert(HabitLog(date: Self.day(-1), habit: h))
        ctx.insert(HabitLog(date: Self.day(0), habit: h))
        try ctx.save()
        // Активны 3 дня (-2, -1, 0), все сделаны → среднее [1.0, 1.0, 1.0] = 1.0.
        let rate = InsightsService.habitsRate(today: Self.today, in: ctx)
        #expect(abs((rate ?? -1) - 1.0) < 0.0001)
    }

    // MARK: — moodRate

    @Test func moodRate_returnsNil_whenNoEntries() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        #expect(InsightsService.moodRate(today: Self.today, in: ctx) == nil)
    }

    @Test func moodRate_normalizesToRate() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // [5, 5, 5] → avg = 5.0 → rate = (5 − 1) / 4 = 1.0
        for i in 0..<3 {
            ctx.insert(JournalEntry(date: Self.day(-i), moodScore: 5))
        }
        try ctx.save()
        #expect(abs((InsightsService.moodRate(today: Self.today, in: ctx) ?? -1) - 1.0) < 0.0001)

        // Очистим и проверим [3] → 0.5
        for entry in (try? ctx.fetch(FetchDescriptor<JournalEntry>())) ?? [] {
            ctx.delete(entry)
        }
        try ctx.save()
        ctx.insert(JournalEntry(date: Self.today, moodScore: 3))
        try ctx.save()
        #expect(abs((InsightsService.moodRate(today: Self.today, in: ctx) ?? -1) - 0.5) < 0.0001)

        // Очистим и проверим [1, 1] → 0.0
        for entry in (try? ctx.fetch(FetchDescriptor<JournalEntry>())) ?? [] {
            ctx.delete(entry)
        }
        try ctx.save()
        ctx.insert(JournalEntry(date: Self.day(-1), moodScore: 1))
        ctx.insert(JournalEntry(date: Self.day(0), moodScore: 1))
        try ctx.save()
        #expect(abs((InsightsService.moodRate(today: Self.today, in: ctx) ?? -1) - 0.0) < 0.0001)
    }

    @Test func moodRate_excludesEntriesOutsideWindow() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        ctx.insert(JournalEntry(date: Self.day(-7), moodScore: 5))   // вне окна
        try ctx.save()
        #expect(InsightsService.moodRate(today: Self.today, in: ctx) == nil)
    }

    // MARK: — topStreaks

    @Test func topStreaks_emptyArray_whenNoHabits() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let result = InsightsService.topStreaks(limit: 3, today: Self.today, in: ctx)
        #expect(result.isEmpty)
    }

    @Test func topStreaks_filtersOutZeroStreaks() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h = Habit(name: "Inactive", colorHex: "2DD4A0", sortOrder: 0)
        h.createdAt = Self.day(-30)
        ctx.insert(h)
        try ctx.save()
        // Логов нет → стрик 0 → не должен попасть в результат.
        let result = InsightsService.topStreaks(limit: 3, today: Self.today, in: ctx)
        #expect(result.isEmpty)
    }

    @Test func topStreaks_sortedDescending_andLimited() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // 4 привычки со стриками 12, 7, 3, 1.
        let configs: [(name: String, streak: Int)] = [
            ("Twelve", 12), ("Seven", 7), ("Three", 3), ("One", 1),
        ]
        for (i, config) in configs.enumerated() {
            let habit = Habit(name: config.name, colorHex: "2DD4A0", sortOrder: i)
            habit.createdAt = Self.day(-30)
            ctx.insert(habit)
            for offset in 0..<config.streak {
                ctx.insert(HabitLog(date: Self.day(-offset), habit: habit))
            }
        }
        try ctx.save()
        let result = InsightsService.topStreaks(limit: 3, today: Self.today, in: ctx)
        #expect(result.count == 3)
        #expect(result[0].value == 12)
        #expect(result[1].value == 7)
        #expect(result[2].value == 3)
    }

    // MARK: — moodSeries

    @Test func moodSeries_returnsExactlySevenEntries() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let series = InsightsService.moodSeries(today: Self.today, in: ctx)
        #expect(series.count == 7)
        for point in series {
            #expect(point.score == nil)
        }
    }

    @Test func moodSeries_orderedFromOldestToToday() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let series = InsightsService.moodSeries(today: Self.today, in: ctx)
        #expect(series.first?.date == Self.day(-6))
        #expect(series.last?.date == Self.day(0))
    }

    @Test func moodSeries_mapsScoresToCorrectDays() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        ctx.insert(JournalEntry(date: Self.day(-3), moodScore: 4))
        ctx.insert(JournalEntry(date: Self.day(0), moodScore: 5))
        try ctx.save()
        let series = InsightsService.moodSeries(today: Self.today, in: ctx)
        #expect(series.count == 7)
        #expect(series[3].score == 4)   // index 3 == day(-3) (0..6 = -6..0)
        #expect(series[6].score == 5)   // index 6 == today
        #expect(series[0].score == nil) // day(-6) — нет записи
    }

    // MARK: — uniqueDataDays

    @Test func uniqueDataDays_zero_whenNoData() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        #expect(InsightsService.uniqueDataDays(today: Self.today, in: ctx) == 0)
    }

    @Test func uniqueDataDays_countsAcrossAllEntities() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // Task сегодня + Habit log вчера + Journal сегодня → 2 уникальных дня.
        let h = Habit(name: "H", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(h)
        ctx.insert(DailyTask(title: "T", date: Self.today))
        ctx.insert(HabitLog(date: Self.day(-1), habit: h))
        ctx.insert(JournalEntry(date: Self.today, moodScore: 4))
        try ctx.save()
        #expect(InsightsService.uniqueDataDays(today: Self.today, in: ctx) == 2)
    }

    @Test func uniqueDataDays_excludesOutsideWindow() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        ctx.insert(DailyTask(title: "Old", date: Self.day(-7)))
        try ctx.save()
        #expect(InsightsService.uniqueDataDays(today: Self.today, in: ctx) == 0)
    }
}
}
