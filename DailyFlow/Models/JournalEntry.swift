import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    var moodScore: Int
    var text: String
    var syncedToObsidian: Bool
    var createdAt: Date
    var updatedAt: Date

    init(date: Date, moodScore: Int = 3, text: String = "") {
        id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.moodScore = moodScore
        self.text = text
        syncedToObsidian = false
        createdAt = .now
        updatedAt = .now
    }
}
