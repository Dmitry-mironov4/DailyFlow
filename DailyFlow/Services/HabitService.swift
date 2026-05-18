import Foundation
import OSLog
import SwiftData
import SwiftUI // Required for Array.move(fromOffsets:toOffset:) extension

private nonisolated(unsafe) let logger = Logger(subsystem: "com.dmitry.DailyFlow", category: "HabitService")

enum HabitService {
    @discardableResult
    static func add(name: String, colorHex: String, in ctx: ModelContext) -> Habit? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing: [Habit]
        do { existing = try ctx.fetch(FetchDescriptor<Habit>()) } catch {
            logger.error("add fetch: \(error.localizedDescription)")
            existing = []
        }
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let habit = Habit(name: trimmed, colorHex: colorHex, sortOrder: nextOrder)
        ctx.insert(habit)
        do { try ctx.save() } catch { logger.error("add save: \(error.localizedDescription)") }
        return habit
    }

    static func update(
        _ habit: Habit,
        name: String,
        colorHex: String,
        reminderTime: Date? = nil,
        in ctx: ModelContext
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { habit.name = trimmed }
        habit.colorHex = colorHex
        habit.reminderTime = reminderTime
        do { try ctx.save() } catch { logger.error("update save: \(error.localizedDescription)") }
    }

    static func delete(_ habit: Habit, in ctx: ModelContext) {
        ctx.delete(habit)
        do { try ctx.save() } catch { logger.error("delete save: \(error.localizedDescription)") }
    }

    static func reorder(_ habits: [Habit], from source: IndexSet, to dest: Int, in ctx: ModelContext) {
        var reordered = habits
        reordered.move(fromOffsets: source, toOffset: dest)
        for (i, habit) in reordered.enumerated() {
            habit.sortOrder = i
        }
        do { try ctx.save() } catch { logger.error("reorder save: \(error.localizedDescription)") }
    }

    static func toggleToday(_ habit: Habit, in ctx: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        if let existing = habit.logs.first(where: { $0.date == today }) {
            ctx.delete(existing)
        } else {
            ctx.insert(HabitLog(date: today, habit: habit))
        }
        do { try ctx.save() } catch { logger.error("toggleToday save: \(error.localizedDescription)") }
    }

    static func isDone(_ habit: Habit, on date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return habit.logs.contains { $0.date == day }
    }

    static func streak(for habit: Habit, relativeTo date: Date, gracePeriod: Int = 1) -> (value: Int, isActive: Bool) {
        let today = Calendar.current.startOfDay(for: date)
        if isDone(habit, on: today) {
            return (consecutiveDays(for: habit, endingAt: today, gracePeriod: gracePeriod), true)
        }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        return (consecutiveDays(for: habit, endingAt: yesterday, gracePeriod: gracePeriod), false)
    }

    private static func consecutiveDays(for habit: Habit, endingAt date: Date, gracePeriod: Int) -> Int {
        var count = 0
        var missedInWindow = 0
        var current = date

        while true {
            if isDone(habit, on: current) {
                count += 1
                missedInWindow = 0
                current = Calendar.current.date(byAdding: .day, value: -1, to: current) ?? current
            } else {
                missedInWindow += 1
                if missedInWindow > gracePeriod { break }
                current = Calendar.current.date(byAdding: .day, value: -1, to: current) ?? current
            }
        }
        return count
    }
}
