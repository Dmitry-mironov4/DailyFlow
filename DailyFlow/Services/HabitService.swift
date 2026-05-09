import Foundation
import SwiftData
import SwiftUI // Required for Array.move(fromOffsets:toOffset:) extension

enum HabitService {
    @discardableResult
    static func add(name: String, colorHex: String, in ctx: ModelContext) -> Habit? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = (try? ctx.fetch(FetchDescriptor<Habit>())) ?? []
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let habit = Habit(name: trimmed, colorHex: colorHex, sortOrder: nextOrder)
        ctx.insert(habit)
        try? ctx.save()
        return habit
    }

    static func update(_ habit: Habit, name: String, colorHex: String, in ctx: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { habit.name = trimmed }
        habit.colorHex = colorHex
        try? ctx.save()
    }

    static func delete(_ habit: Habit, in ctx: ModelContext) {
        ctx.delete(habit)
        try? ctx.save()
    }

    static func reorder(_ habits: [Habit], from source: IndexSet, to dest: Int, in ctx: ModelContext) {
        var reordered = habits
        reordered.move(fromOffsets: source, toOffset: dest)
        for (i, habit) in reordered.enumerated() {
            habit.sortOrder = i
        }
        try? ctx.save()
    }

    static func toggleToday(_ habit: Habit, in ctx: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        if let existing = habit.logs.first(where: { $0.date == today }) {
            ctx.delete(existing)
        } else {
            ctx.insert(HabitLog(date: today, habit: habit))
        }
        try? ctx.save()
    }

    static func isDone(_ habit: Habit, on date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return habit.logs.contains { $0.date == day }
    }

    static func streak(for habit: Habit, relativeTo date: Date) -> (value: Int, isActive: Bool) {
        let today = Calendar.current.startOfDay(for: date)
        if isDone(habit, on: today) {
            return (consecutiveDays(for: habit, endingAt: today), true)
        }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        return (consecutiveDays(for: habit, endingAt: yesterday), false)
    }

    private static func consecutiveDays(for habit: Habit, endingAt date: Date) -> Int {
        var count = 0
        var current = date
        while isDone(habit, on: current) {
            count += 1
            current = Calendar.current.date(byAdding: .day, value: -1, to: current)!
        }
        return count
    }
}
