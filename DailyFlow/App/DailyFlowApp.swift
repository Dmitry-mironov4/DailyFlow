import SwiftData
import SwiftUI

@main
struct DailyFlowApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            DailyTask.self,
            Habit.self,
            HabitLog.self,
            JournalEntry.self,
        ])
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await CalendarService.requestAccess() }
        }
        .modelContainer(container)
    }
}
