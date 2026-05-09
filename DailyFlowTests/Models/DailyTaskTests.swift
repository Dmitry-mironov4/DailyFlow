import Foundation
import Testing
import SwiftData
@testable import DailyFlow

extension DailyFlowTests {
    @Suite("DailyTask", .serialized) @MainActor
    struct DailyTaskTests {
        @Test func init_normalizesDateToStartOfDay() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let date = Date()
            let task = DailyTask(title: "Test", date: date)
            ctx.insert(task)
            let expected = Calendar.current.startOfDay(for: date)
            #expect(task.date == expected)
        }

        @Test func init_defaultsAreCorrect() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let task = DailyTask(title: "Test", date: .now)
            ctx.insert(task)
            #expect(task.isFocus == false)
            #expect(task.isCompleted == false)
            #expect(task.completedAt == nil)
        }

        @Test func init_withFocus() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let task = DailyTask(title: "Focus", date: .now, isFocus: true)
            ctx.insert(task)
            #expect(task.isFocus == true)
        }
    }
}
