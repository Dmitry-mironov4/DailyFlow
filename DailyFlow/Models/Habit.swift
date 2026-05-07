import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID
    var name: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog]

    init(name: String, colorHex: String, sortOrder: Int = 0) {
        id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        createdAt = .now
        logs = []
    }
}
