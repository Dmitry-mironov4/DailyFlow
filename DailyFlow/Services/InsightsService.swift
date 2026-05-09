import Foundation
import SwiftData

enum InsightsService {

    // MARK: — Окно

    /// Возвращает (start, end) окна [today−6 ... today], обе даты на startOfDay.
    private static func window(today: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: today)
        let start = cal.date(byAdding: .day, value: -6, to: end)!
        return (start, end)
    }

    // MARK: — tasksRate

    /// Доля выполненных задач за окно [today−6 ... today]. nil если задач 0.
    /// Возвращает значение в [0.0 ... 1.0].
    static func tasksRate(today: Date, in ctx: ModelContext) -> Double? {
        let (start, end) = window(today: today)
        let predicate = #Predicate<DailyTask> { $0.date >= start && $0.date <= end }
        guard let tasks = try? ctx.fetch(FetchDescriptor<DailyTask>(predicate: predicate)),
              !tasks.isEmpty else { return nil }
        let completed = tasks.lazy.filter(\.isCompleted).count
        return Double(completed) / Double(tasks.count)
    }

    // MARK: — habitsRate

    /// Среднее «дневной доли выполненных привычек» по окну.
    /// Для каждого дня окна с активными привычками (createdAt.startOfDay <= day)
    /// считаем activeLogs / activeHabits. Возвращает среднее в [0...1].
    /// nil если ни одного активного дня.
    static func habitsRate(today: Date, in ctx: ModelContext) -> Double? {
        let (start, end) = window(today: today)
        let cal = Calendar.current
        guard let habits = try? ctx.fetch(FetchDescriptor<Habit>()) else { return nil }
        if habits.isEmpty { return nil }

        // Собираем все даты окна (7 шт.) от start до end включительно.
        var dates: [Date] = []
        var cursor = start
        while cursor <= end {
            dates.append(cursor)
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }

        var dailyRates: [Double] = []
        for day in dates {
            let activeHabits = habits.filter { cal.startOfDay(for: $0.createdAt) <= day }
            if activeHabits.isEmpty { continue }
            let activeLogs = activeHabits.reduce(0) { acc, habit in
                acc + habit.logs.filter { $0.date == day }.count
            }
            dailyRates.append(Double(activeLogs) / Double(activeHabits.count))
        }
        if dailyRates.isEmpty { return nil }
        return dailyRates.reduce(0, +) / Double(dailyRates.count)
    }
}
