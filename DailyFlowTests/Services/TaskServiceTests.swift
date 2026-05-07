import Foundation
import SwiftData
import Testing
@testable import DailyFlow

@Suite("TaskService") @MainActor
struct TaskServiceTests {
    private func makeContext() throws -> ModelContext {
        try TestContainer.make().mainContext
    }

    private var today: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private func yesterday() throws -> Date {
        try #require(Calendar.current.date(byAdding: .day, value: -1, to: today))
    }

    @Test func add_returnsNilForEmptyTitle() throws {
        let ctx = try makeContext()
        let result = TaskService.add(title: "", on: today, in: ctx)
        #expect(result == nil)
    }

    @Test func add_returnsNilForWhitespaceOnlyTitle() throws {
        let ctx = try makeContext()
        let result = TaskService.add(title: "   ", on: today, in: ctx)
        #expect(result == nil)
    }

    @Test func add_trimsWhitespace() throws {
        let ctx = try makeContext()
        let task = TaskService.add(title: "  Задача  ", on: today, in: ctx)
        #expect(task?.title == "Задача")
    }

    @Test func toggleCompletion_setsCompletedAt() throws {
        let ctx = try makeContext()
        let task = DailyTask(title: "Test", date: today)
        ctx.insert(task)
        TaskService.toggleCompletion(task, in: ctx)
        #expect(task.isCompleted == true)
        #expect(task.completedAt != nil)
    }

    @Test func toggleCompletion_unsetsCompletedAt_whenUntoggled() throws {
        let ctx = try makeContext()
        let task = DailyTask(title: "Test", date: today)
        ctx.insert(task)
        TaskService.toggleCompletion(task, in: ctx)
        TaskService.toggleCompletion(task, in: ctx)
        #expect(task.isCompleted == false)
        #expect(task.completedAt == nil)
    }

    @Test func setFocus_clearsPreviousFocusOnSameDay() throws {
        let ctx = try makeContext()
        let first = DailyTask(title: "First", date: today, isFocus: true)
        let second = DailyTask(title: "Second", date: today)
        ctx.insert(first)
        ctx.insert(second)
        try TaskService.setFocus(second, in: ctx)
        #expect(first.isFocus == false)
        #expect(second.isFocus == true)
    }

    @Test func setFocus_doesNotAffectOtherDays() throws {
        let ctx = try makeContext()
        let otherDay = try #require(Calendar.current.date(byAdding: .day, value: -2, to: today))
        let old = DailyTask(title: "Old", date: otherDay, isFocus: true)
        let newTask = DailyTask(title: "New", date: today)
        ctx.insert(old)
        ctx.insert(newTask)
        try TaskService.setFocus(newTask, in: ctx)
        #expect(old.isFocus == true)
        #expect(newTask.isFocus == true)
    }

    @Test func clearFocus_removesAllFocusFlagsOnDay() throws {
        let ctx = try makeContext()
        let task = DailyTask(title: "Focus", date: today, isFocus: true)
        ctx.insert(task)
        try TaskService.clearFocus(on: today, in: ctx)
        #expect(task.isFocus == false)
    }

    @Test func updateTitle_ignoresEmpty() throws {
        let ctx = try makeContext()
        let task = DailyTask(title: "Original", date: today)
        ctx.insert(task)
        TaskService.updateTitle(task, to: "", in: ctx)
        #expect(task.title == "Original")
    }

    @Test func rolloverPending_movesIncompleteFromPastDays() throws {
        let ctx = try makeContext()
        let yest = try yesterday()
        let old = DailyTask(title: "Old", date: yest)
        ctx.insert(old)
        let count = try TaskService.rolloverPending(into: today, in: ctx)
        #expect(count == 1)
        #expect(old.date == today)
    }

    @Test func rolloverPending_preservesTitle_dropsFocusFlag() throws {
        let ctx = try makeContext()
        let yest = try yesterday()
        let old = DailyTask(title: "Important", date: yest, isFocus: true)
        ctx.insert(old)
        try TaskService.rolloverPending(into: today, in: ctx)
        #expect(old.title == "Important")
        #expect(old.isFocus == false)
    }

    @Test func rolloverPending_skipsCompletedTasks() throws {
        let ctx = try makeContext()
        let yest = try yesterday()
        let done = DailyTask(title: "Done", date: yest)
        done.isCompleted = true
        ctx.insert(done)
        let count = try TaskService.rolloverPending(into: today, in: ctx)
        #expect(count == 0)
        #expect(done.date == yest)
    }

    @Test func discardPending_deletesOnlyPastIncomplete() throws {
        let ctx = try makeContext()
        let yest = try yesterday()
        let old = DailyTask(title: "Old", date: yest)
        let todayTask = DailyTask(title: "Today", date: today)
        ctx.insert(old)
        ctx.insert(todayTask)
        let count = try TaskService.discardPending(before: today, in: ctx)
        #expect(count == 1)
        let all = try ctx.fetch(FetchDescriptor<DailyTask>())
        #expect(all.count == 1)
        #expect(all.first?.title == "Today")
    }
}
