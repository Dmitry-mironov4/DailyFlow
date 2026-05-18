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
            TaskList.self,
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
                .onAppear { seedDefaultLists() }
        }
        .modelContainer(container)
    }

    private func seedDefaultLists() {
        let ctx = container.mainContext
        guard (try? ctx.fetch(FetchDescriptor<TaskList>()))?.isEmpty == true else { return }
        let defaults: [(String, String, Int)] = [
            ("Входящие", "📥", 0), ("Учёба", "🎓", 1),
            ("Личное", "👤", 2), ("Работа", "💼", 3)
        ]
        for (name, emoji, order) in defaults {
            ctx.insert(TaskList(name: name, emoji: emoji, sortOrder: order))
        }
        try? ctx.save()
    }
}
