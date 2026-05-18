import Foundation
import SwiftData

enum TaskService {
    @discardableResult
    static func add(
        title: String,
        scheduledTime: Date? = nil,
        isFocus: Bool = false,
        on date: Date,
        in ctx: ModelContext
    ) -> DailyTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let task = DailyTask(title: trimmed, date: date, isFocus: isFocus, scheduledTime: scheduledTime)
        ctx.insert(task)
        task.calendarEventID = CalendarService.sync(task)
        return task
    }

    static func toggleCompletion(_ task: DailyTask, in ctx: ModelContext) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? .now : nil
        try? ctx.save()
    }

    static func setFocus(_ task: DailyTask, in ctx: ModelContext) throws {
        let targetDay = task.date
        let all = try ctx.fetch(FetchDescriptor<DailyTask>())
        for existing in all where existing.date == targetDay && existing.isFocus {
            existing.isFocus = false
        }
        task.isFocus = true
        try ctx.save()
    }

    static func clearFocus(on date: Date, in ctx: ModelContext) throws {
        let day = Calendar.current.startOfDay(for: date)
        let all = try ctx.fetch(FetchDescriptor<DailyTask>())
        for task in all where task.date == day && task.isFocus {
            task.isFocus = false
        }
        try ctx.save()
    }

    static func delete(_ task: DailyTask, in ctx: ModelContext) {
        if let eventID = task.calendarEventID {
            CalendarService.remove(eventID: eventID)
        }
        ctx.delete(task)
        try? ctx.save()
    }

    static func updateTitle(_ task: DailyTask, to title: String, in ctx: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        task.title = trimmed
        task.calendarEventID = CalendarService.sync(task)
        try? ctx.save()
    }

    static func setScheduledTime(_ task: DailyTask, time: Date?, in ctx: ModelContext) {
        if let time {
            task.scheduledTime = time
            task.calendarEventID = CalendarService.sync(task)
        } else {
            if let eventID = task.calendarEventID {
                CalendarService.remove(eventID: eventID)
                task.calendarEventID = nil
            }
            task.scheduledTime = nil
        }
        try? ctx.save()
    }

    @discardableResult
    static func rolloverPending(into target: Date, in ctx: ModelContext) throws -> Int {
        let targetDay = Calendar.current.startOfDay(for: target)
        let all = try ctx.fetch(FetchDescriptor<DailyTask>())
        let pending = all.filter { $0.date < targetDay && !$0.isCompleted }
        for task in pending {
            task.date = targetDay
            task.isFocus = false
        }
        try ctx.save()
        return pending.count
    }

    @discardableResult
    static func discardPending(before date: Date, in ctx: ModelContext) throws -> Int {
        let day = Calendar.current.startOfDay(for: date)
        let all = try ctx.fetch(FetchDescriptor<DailyTask>())
        let pending = all.filter { $0.date < day && !$0.isCompleted }
        for task in pending {
            ctx.delete(task)
        }
        try ctx.save()
        return pending.count
    }
}
