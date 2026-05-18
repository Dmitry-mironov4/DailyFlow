// swiftlint:disable file_length
import Foundation
import OSLog
import SwiftData

private nonisolated(unsafe) let logger = Logger(subsystem: "com.dmitry.DailyFlow", category: "InsightsService")

/// Запись о текущем стрике одной привычки.
struct StreakItem: Identifiable {
    let habit: Habit
    let value: Int
    let isActive: Bool
    var id: UUID {
        habit.id
    }
}

/// Точка серии настроения за один день. score == nil → нет записи в этот день.
struct MoodPoint: Identifiable {
    let date: Date
    let score: Int?
    var id: Date {
        date
    }
}

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
        guard let habits = try? ctx.fetch(FetchDescriptor<Habit>()),
              !habits.isEmpty else { return nil }

        var allLogs: [HabitLog] = []
        do { allLogs = try ctx.fetch(FetchDescriptor<HabitLog>()) } catch {
            logger.error("habitsRate fetch logs: \(error.localizedDescription)")
        }

        // O(n) grouping вместо O(n×m)
        let logsByDate = Dictionary(grouping: allLogs) { $0.date }

        var dates: [Date] = []
        var cursor = start
        while cursor <= end {
            dates.append(cursor)
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }

        var dailyRates: [Double] = []
        for day in dates {
            let activeHabits = habits.filter { cal.startOfDay(for: $0.createdAt) <= day }
            if activeHabits.isEmpty { continue }
            let loggedHabitIDs = Set((logsByDate[day] ?? []).compactMap { $0.habit?.id })
            let activeDone = activeHabits.count(where: { loggedHabitIDs.contains($0.id) })
            dailyRates.append(Double(activeDone) / Double(activeHabits.count))
        }
        if dailyRates.isEmpty { return nil }
        return dailyRates.reduce(0, +) / Double(dailyRates.count)
    }

    // MARK: — moodRate

    /// Среднее настроение за окно, нормированное в [0...1].
    /// rate = (avg − 1) / 4, где avg = среднее JournalEntry.moodScore.
    /// nil если 0 записей.
    static func moodRate(today: Date, in ctx: ModelContext) -> Double? {
        let (start, end) = window(today: today)
        let predicate = #Predicate<JournalEntry> { $0.date >= start && $0.date <= end }
        guard let entries = try? ctx.fetch(FetchDescriptor<JournalEntry>(predicate: predicate)),
              !entries.isEmpty else { return nil }
        let sum = entries.reduce(0) { $0 + $1.moodScore }
        let avg = Double(sum) / Double(entries.count)
        return (avg - 1.0) / 4.0
    }

    // MARK: — topStreaks

    /// Топ-N привычек по value текущего стрика. Сортирует по убыванию value,
    /// фильтрует value > 0. Использует HabitService.streak(for:relativeTo:).
    static func topStreaks(
        limit: Int,
        today: Date,
        in ctx: ModelContext
    ) -> [StreakItem] {
        guard let habits = try? ctx.fetch(FetchDescriptor<Habit>()) else { return [] }
        let scored = habits.map { habit -> StreakItem in
            let streak = HabitService.streak(for: habit, relativeTo: today)
            return StreakItem(habit: habit, value: streak.value, isActive: streak.isActive)
        }
        return scored
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.self)
    }

    // MARK: — moodSeries

    /// Ровно 7 элементов от today−6 до today. score == nil → нет записи в этот день.
    static func moodSeries(today: Date, in ctx: ModelContext) -> [MoodPoint] {
        let (start, end) = window(today: today)
        let cal = Calendar.current
        let predicate = #Predicate<JournalEntry> { $0.date >= start && $0.date <= end }
        let entries = (try? ctx.fetch(FetchDescriptor<JournalEntry>(predicate: predicate))) ?? []
        let byDate = Dictionary(uniqueKeysWithValues: entries.map { ($0.date, $0.moodScore) })

        var result: [MoodPoint] = []
        var cursor = start
        while cursor <= end {
            result.append(MoodPoint(date: cursor, score: byDate[cursor]))
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return result
    }

    // MARK: — Предыдущее окно (today−14 ... today−8)

    private static func previousWindow(today: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: cal.date(byAdding: .day, value: -8, to: today)!)
        let start = cal.date(byAdding: .day, value: -6, to: end)!
        return (start, end)
    }

    static func previousTasksRate(today: Date, in ctx: ModelContext) -> Double? {
        let (start, end) = previousWindow(today: today)
        let predicate = #Predicate<DailyTask> { $0.date >= start && $0.date <= end }
        guard let tasks = try? ctx.fetch(FetchDescriptor<DailyTask>(predicate: predicate)),
              !tasks.isEmpty else { return nil }
        return Double(tasks.filter(\.isCompleted).count) / Double(tasks.count)
    }

    static func previousHabitsRate(today: Date, in ctx: ModelContext) -> Double? {
        let (start, end) = previousWindow(today: today)
        let cal = Calendar.current
        guard let habits = try? ctx.fetch(FetchDescriptor<Habit>()),
              !habits.isEmpty else { return nil }
        var dates: [Date] = []
        var cursor = start
        while cursor <= end {
            dates.append(cursor)
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        var dailyRates: [Double] = []
        for day in dates {
            let active = habits.filter { cal.startOfDay(for: $0.createdAt) <= day }
            if active.isEmpty { continue }
            let logs = active.reduce(0) { $0 + $1.logs.count(where: { $0.date == day }) }
            dailyRates.append(Double(logs) / Double(active.count))
        }
        guard !dailyRates.isEmpty else { return nil }
        return dailyRates.reduce(0, +) / Double(dailyRates.count)
    }

    static func previousMoodRate(today: Date, in ctx: ModelContext) -> Double? {
        let (start, end) = previousWindow(today: today)
        let predicate = #Predicate<JournalEntry> { $0.date >= start && $0.date <= end }
        guard let entries = try? ctx.fetch(FetchDescriptor<JournalEntry>(predicate: predicate)),
              !entries.isEmpty else { return nil }
        let avg = Double(entries.reduce(0) { $0 + $1.moodScore }) / Double(entries.count)
        return (avg - 1.0) / 4.0
    }

    // MARK: — uniqueDataDays

    /// Количество уникальных дней в окне с хотя бы одной записью
    /// в DailyTask, HabitLog или JournalEntry.
    static func uniqueDataDays(today: Date, in ctx: ModelContext) -> Int {
        let (start, end) = window(today: today)
        var dates = Set<Date>()

        let taskPred = #Predicate<DailyTask> { $0.date >= start && $0.date <= end }
        let logPred = #Predicate<HabitLog> { $0.date >= start && $0.date <= end }
        let entryPred = #Predicate<JournalEntry> { $0.date >= start && $0.date <= end }

        if let tasks = try? ctx.fetch(FetchDescriptor<DailyTask>(predicate: taskPred)) {
            dates.formUnion(tasks.map(\.date))
        }
        if let logs = try? ctx.fetch(FetchDescriptor<HabitLog>(predicate: logPred)) {
            dates.formUnion(logs.map(\.date))
        }
        if let entries = try? ctx.fetch(FetchDescriptor<JournalEntry>(predicate: entryPred)) {
            dates.formUnion(entries.map(\.date))
        }
        return dates.count
    }

    // MARK: — habitMoodCorrelations (D2)

    /// Для каждой привычки считает дельту настроения: среднее в дни выполнения − среднее в дни пропуска.
    /// Возвращает топ-3 привычки с delta > 0.3, отсортированные по убыванию.
    /// Требует минимум 7 дней с записями настроения и лога.
    static func habitMoodCorrelations(
        habits: [Habit],
        logs: [HabitLog],
        entries: [JournalEntry],
        in window: [Date]
    ) -> [(habit: Habit, delta: Double)] {
        guard window.count >= 7 else { return [] }

        let moodByDate = Dictionary(uniqueKeysWithValues: entries.compactMap { entry -> (Date, Double)? in
            (entry.date, Double(entry.moodScore))
        })

        guard moodByDate.count >= 7 else { return [] }

        var result: [(habit: Habit, delta: Double)] = []

        for habit in habits {
            let doneDates = Set(logs.filter { $0.habit?.id == habit.id }.map(\.date))
            let doneScores = window.compactMap { doneDates.contains($0) ? moodByDate[$0] : nil }
            let missScores = window.compactMap { !doneDates.contains($0) ? moodByDate[$0] : nil }

            guard !doneScores.isEmpty, !missScores.isEmpty else { continue }
            let avgDone = doneScores.reduce(0, +) / Double(doneScores.count)
            let avgMiss = missScores.reduce(0, +) / Double(missScores.count)
            let delta = avgDone - avgMiss
            if delta > 0.3 { result.append((habit: habit, delta: delta)) }
        }

        return result.sorted { $0.delta > $1.delta }.prefix(3).map(\.self)
    }
}
