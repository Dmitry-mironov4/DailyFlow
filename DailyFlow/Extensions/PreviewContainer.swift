import SwiftData
import SwiftUI

enum PreviewScenario {
    case empty
    case onlyFocus
    case mixed
    case withRollover
    case editingFirst
}

extension ModelContainer {
    @MainActor
    static func preview(_ scenario: PreviewScenario) -> ModelContainer {
        let schema = Schema([DailyTask.self, Habit.self, HabitLog.self, JournalEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: schema, configurations: [config])
        let ctx = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)

        switch scenario {
        case .empty:
            break

        case .onlyFocus:
            ctx.insert(DailyTask(title: "Сделать архитектуру экрана", date: today, isFocus: true))

        case .mixed:
            ctx.insert(DailyTask(title: "Спроектировать базу данных", date: today, isFocus: true))
            ctx.insert(DailyTask(title: "Написать тесты сервиса", date: today))
            ctx.insert(DailyTask(title: "Проверить цветовые токены", date: today))
            let done = DailyTask(title: "Выполненная задача", date: today)
            done.isCompleted = true
            done.completedAt = .now
            ctx.insert(done)

        case .withRollover:
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            ctx.insert(DailyTask(title: "Не перенёс вчера", date: yesterday))
            ctx.insert(DailyTask(title: "Ещё одна старая задача", date: yesterday))
            ctx.insert(DailyTask(title: "Задача сегодня", date: today))

        case .editingFirst:
            ctx.insert(DailyTask(title: "Задача в режиме редактирования", date: today))
        }

        return container
    }
}
