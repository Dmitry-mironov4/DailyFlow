import Foundation
import SwiftData

enum TaskService {
    @discardableResult
    static func add(
        title: String,
        isFocus: Bool = false,
        on date: Date,
        in ctx: ModelContext
    ) -> DailyTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let task = DailyTask(title: trimmed, date: date, isFocus: isFocus)
        ctx.insert(task)
        return task
    }

    static func toggleCompletion(_ task: DailyTask, in ctx: ModelContext) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? .now : nil
        try? ctx.save()
    }

    static func setFocus(_ task: DailyTask, in ctx: ModelContext) throws {
        let targetDay = task.date
        let descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate { $0.date == targetDay && $0.isFocus == true }
        )
        let existing = try ctx.fetch(descriptor)
        for existing in existing {
            existing.isFocus = false
        }
        task.isFocus = true
        try ctx.save()
    }

    static func clearFocus(on date: Date, in ctx: ModelContext) throws {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate { $0.date == day && $0.isFocus == true }
        )
        let focused = try ctx.fetch(descriptor)
        for focused in focused {
            focused.isFocus = false
        }
        try ctx.save()
    }

    static func delete(_ task: DailyTask, in ctx: ModelContext) {
        ctx.delete(task)
        try? ctx.save()
    }

    static func updateTitle(_ task: DailyTask, to title: String, in ctx: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        task.title = trimmed
        try? ctx.save()
    }

    @discardableResult
    static func rolloverPending(into target: Date, in ctx: ModelContext) throws -> Int {
        let targetDay = Calendar.current.startOfDay(for: target)
        let descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate { $0.date < targetDay && $0.isCompleted == false }
        )
        let pending = try ctx.fetch(descriptor)
        for pending in pending {
            pending.date = targetDay
            pending.isFocus = false
        }
        try ctx.save()
        return pending.count
    }

    @discardableResult
    static func discardPending(before date: Date, in ctx: ModelContext) throws -> Int {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate { $0.date < day && $0.isCompleted == false }
        )
        let pending = try ctx.fetch(descriptor)
        for pending in pending {
            ctx.delete(pending)
        }
        try ctx.save()
        return pending.count
    }
}
