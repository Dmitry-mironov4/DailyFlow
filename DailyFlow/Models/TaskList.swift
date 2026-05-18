import Foundation
import SwiftData

@Model
final class TaskList {
    var id: UUID
    var name: String
    var emoji: String
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \DailyTask.list)
    var tasks: [DailyTask] = []

    init(name: String, emoji: String, sortOrder: Int) {
        id = UUID()
        self.name = name
        self.emoji = emoji
        self.sortOrder = sortOrder
        createdAt = .now
    }
}
