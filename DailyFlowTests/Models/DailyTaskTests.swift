import Foundation
import Testing
@testable import DailyFlow

@Suite("DailyTask") @MainActor
struct DailyTaskTests {
    @Test func init_normalizesDateToStartOfDay() {
        let date = Date()
        let task = DailyTask(title: "Test", date: date)
        let expected = Calendar.current.startOfDay(for: date)
        #expect(task.date == expected)
    }

    @Test func init_defaultsAreCorrect() {
        let task = DailyTask(title: "Test", date: .now)
        #expect(task.isFocus == false)
        #expect(task.isCompleted == false)
        #expect(task.completedAt == nil)
    }

    @Test func init_withFocus() {
        let task = DailyTask(title: "Focus", date: .now, isFocus: true)
        #expect(task.isFocus == true)
    }
}
