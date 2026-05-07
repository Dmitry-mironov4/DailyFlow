import Foundation
import SwiftData
@testable import DailyFlow

@MainActor
enum TestContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            DailyTask.self,
            Habit.self,
            HabitLog.self,
            JournalEntry.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
