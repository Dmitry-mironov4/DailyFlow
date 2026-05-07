import Foundation
import SwiftData

@Model
final class DailyTask {
    var id: UUID
    var title: String
    var isFocus: Bool
    var isCompleted: Bool
    var date: Date
    var createdAt: Date
    var completedAt: Date?

    init(title: String, date: Date, isFocus: Bool = false) {
        id = UUID()
        self.title = title
        self.isFocus = isFocus
        isCompleted = false
        self.date = Calendar.current.startOfDay(for: date)
        createdAt = .now
        completedAt = nil
    }
}
