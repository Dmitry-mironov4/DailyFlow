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
                .task { _ = await CalendarService.requestAccess() }
        }
        .modelContainer(container)
    }

    private func seedDefaultLists() {
        let ctx = container.mainContext
        guard (try? ctx.fetch(FetchDescriptor<TaskList>()))?.isEmpty == true else { return }
        struct ListSeed { let name: String
            let emoji: String
            let order: Int
        }
        let defaults = [
            ListSeed(name: "Входящие", emoji: "📥", order: 0),
            ListSeed(name: "Учёба", emoji: "🎓", order: 1),
            ListSeed(name: "Личное", emoji: "👤", order: 2),
            ListSeed(name: "Работа", emoji: "💼", order: 3),
        ]
        for seed in defaults {
            ctx.insert(TaskList(name: seed.name, emoji: seed.emoji, sortOrder: seed.order))
        }
        try? ctx.save()
    }
}
