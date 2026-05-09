import Testing
import Foundation
import SwiftData
@testable import DailyFlow

@Suite("HabitService") @MainActor
struct HabitServiceTests {

    // MARK: — add

    @Test func add_returnsNilForEmptyName() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        #expect(HabitService.add(name: "   ", colorHex: "2DD4A0", in: ctx) == nil)
    }

    @Test func add_assignsIncrementingSortOrder() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h1 = HabitService.add(name: "First", colorHex: "2DD4A0", in: ctx)
        let h2 = HabitService.add(name: "Second", colorHex: "F0A23B", in: ctx)
        #expect(h1?.sortOrder == 0)
        #expect(h2?.sortOrder == 1)
    }

    // MARK: — update

    @Test func update_ignoresEmptyName() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Original", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.update(habit, name: "  ", colorHex: "F0A23B", in: ctx)
        #expect(habit.name == "Original")
        #expect(habit.colorHex == "F0A23B")
    }

    @Test func update_appliesNameAndColor() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Original", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.update(habit, name: "Updated", colorHex: "9B8AE8", in: ctx)
        #expect(habit.name == "Updated")
        #expect(habit.colorHex == "9B8AE8")
    }

    // MARK: — toggleToday / isDone

    @Test func toggleToday_createsLog() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.toggleToday(habit, in: ctx)
        #expect(habit.logs.count == 1)
        #expect(HabitService.isDone(habit, on: .now))
    }

    @Test func toggleToday_removesLogOnSecondCall() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.toggleToday(habit, in: ctx)
        HabitService.toggleToday(habit, in: ctx)
        #expect(habit.logs.isEmpty)
        #expect(!HabitService.isDone(habit, on: .now))
    }

    @Test func toggleToday_idempotentOnThirdCall() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.toggleToday(habit, in: ctx)
        HabitService.toggleToday(habit, in: ctx)
        HabitService.toggleToday(habit, in: ctx)
        #expect(habit.logs.count == 1)
    }

    @Test func isDone_returnsFalseWhenNoLog() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        #expect(!HabitService.isDone(habit, on: .now))
    }

    @Test func isDone_returnsTrueWhenLogExists() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.toggleToday(habit, in: ctx)
        #expect(HabitService.isDone(habit, on: .now))
    }

    // MARK: — streak

    @Test func streak_returnsZeroAndInactiveWhenNeverDone() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        let result = HabitService.streak(for: habit, relativeTo: .now)
        #expect(result.value == 0)
        #expect(!result.isActive)
    }

    @Test func streak_returnsOneAndActiveWhenDoneToday() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.toggleToday(habit, in: ctx)
        let result = HabitService.streak(for: habit, relativeTo: .now)
        #expect(result.value == 1)
        #expect(result.isActive)
    }

    @Test func streak_returnsYesterdayCountAndInactiveWhenNotDoneToday() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        let yesterday = Calendar.current.date(
            byAdding: .day, value: -1,
            to: Calendar.current.startOfDay(for: .now)
        )!
        ctx.insert(HabitLog(date: yesterday, habit: habit))
        let result = HabitService.streak(for: habit, relativeTo: .now)
        #expect(result.value == 1)
        #expect(!result.isActive)
    }

    @Test func streak_breaksOnMissedDay() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        let today = Calendar.current.startOfDay(for: .now)
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        // Сделано сегодня и два дня назад, вчера — пропуск
        ctx.insert(HabitLog(date: today, habit: habit))
        ctx.insert(HabitLog(date: twoDaysAgo, habit: habit))
        let result = HabitService.streak(for: habit, relativeTo: .now)
        #expect(result.value == 1)   // только сегодня, вчера — разрыв
        #expect(result.isActive)
    }

    // MARK: — reorder

    @Test func reorder_updatesSortOrder() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h1 = Habit(name: "A", colorHex: "2DD4A0", sortOrder: 0)
        let h2 = Habit(name: "B", colorHex: "F0A23B", sortOrder: 1)
        let h3 = Habit(name: "C", colorHex: "9B8AE8", sortOrder: 2)
        [h1, h2, h3].forEach { ctx.insert($0) }
        // Переместить первый элемент в конец: [h1,h2,h3] → [h2,h3,h1]
        HabitService.reorder([h1, h2, h3], from: IndexSet(integer: 0), to: 3, in: ctx)
        #expect(h2.sortOrder == 0)
        #expect(h3.sortOrder == 1)
        #expect(h1.sortOrder == 2)
    }

    // MARK: — delete

    @Test func delete_cascadesLogs() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.toggleToday(habit, in: ctx)
        #expect(habit.logs.count == 1)
        HabitService.delete(habit, in: ctx)
        let remaining = try ctx.fetch(FetchDescriptor<HabitLog>())
        #expect(remaining.isEmpty)
    }
}
