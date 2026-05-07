import Foundation
import SwiftData

@Model
final class HabitLog {
    var id: UUID
    var date: Date
    var completedAt: Date
    var habit: Habit?

    init(date: Date, completedAt: Date = .now, habit: Habit? = nil) {
        id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.completedAt = completedAt
        self.habit = habit
    }
}
