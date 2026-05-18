import SwiftData
import SwiftUI

enum PreviewScenario {
    case empty
    case onlyFocus
    case mixed
    case withRollover
    case editingFirst
    // Привычки:
    case threeHabits
    case allHabitsDoneToday
    case longStreak
    /// Инсайты:
    case fullWeek
    // Дневник:
    case emptyJournal
    case moodOnly
    case fullJournal
    case longJournal
}

extension ModelContainer {
    // swiftlint:disable cyclomatic_complexity function_body_length
    @MainActor
    static func preview(_ scenario: PreviewScenario) -> ModelContainer {
        let schema = Schema([DailyTask.self, Habit.self, HabitLog.self, JournalEntry.self, TaskList.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            fatalError("Preview container init failed")
        }
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

        case .threeHabits:
            let h1 = Habit(name: "Медитация", colorHex: "808080", sortOrder: 0)
            let h2 = Habit(name: "Спорт", colorHex: "808080", sortOrder: 1)
            let h3 = Habit(name: "Чтение", colorHex: "808080", sortOrder: 2)
            [h1, h2, h3].forEach { ctx.insert($0) }
            // h1 выполнена сегодня
            ctx.insert(HabitLog(date: today, habit: h1))
            // h2 выполнена вчера (стрик 1, серый)
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            ctx.insert(HabitLog(date: yesterday, habit: h2))

        case .allHabitsDoneToday:
            let h1 = Habit(name: "Медитация", colorHex: "808080", sortOrder: 0)
            let h2 = Habit(name: "Спорт", colorHex: "808080", sortOrder: 1)
            let h3 = Habit(name: "Чтение", colorHex: "808080", sortOrder: 2)
            [h1, h2, h3].forEach { ctx.insert($0) }
            [h1, h2, h3].forEach { ctx.insert(HabitLog(date: today, habit: $0)) }

        case .longStreak:
            let h1 = Habit(name: "Медитация", colorHex: "808080", sortOrder: 0)
            let h2 = Habit(name: "Спорт", colorHex: "808080", sortOrder: 1)
            ctx.insert(h1)
            ctx.insert(h2)
            // h1: стрик 7 дней подряд включая сегодня
            for i in 0 ..< 7 {
                let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
                ctx.insert(HabitLog(date: date, habit: h1))
            }
            // h2: стрик 3 дня, но сегодня не выполнена (серая цифра 3)
            for i in 1 ... 3 {
                let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
                ctx.insert(HabitLog(date: date, habit: h2))
            }

        case .fullWeek:
            seedFullWeek(in: ctx, today: today)

        case .emptyJournal:
            break

        case .moodOnly:
            ctx.insert(JournalEntry(date: today, moodScore: 4, text: ""))

        case .fullJournal:
            ctx.insert(JournalEntry(
                date: today,
                moodScore: 5,
                text: "Сегодня прошёл день в потоке. Завершил спецификацию журнала, прошлись по всем edge-кейсам, спокойно."
            ))

        case .longJournal:
            let longText = String(repeating: "Длинный текст записи. ", count: 100)
            ctx.insert(JournalEntry(date: today, moodScore: 3, text: longText))
        }

        return container
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    @MainActor
    private static func seedFullWeek(in ctx: ModelContext, today: Date) {
        let cal = Calendar.current
        // 7 дней задач: ~70% выполнения.
        for offset in 0 ..< 7 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let count = offset % 2 == 0 ? 3 : 2
            for index in 0 ..< count {
                let task = DailyTask(title: "Задача \(index + 1)", date: day)
                if (offset + index) % 3 != 0 {
                    task.isCompleted = true
                    task.completedAt = .now
                }
                ctx.insert(task)
            }
        }
        // 3 привычки старого возраста, разные стрики.
        let h1 = Habit(name: "Медитация", colorHex: "808080", sortOrder: 0)
        let h2 = Habit(name: "Спорт", colorHex: "808080", sortOrder: 1)
        let h3 = Habit(name: "Чтение", colorHex: "808080", sortOrder: 2)
        for habit in [h1, h2, h3] {
            habit.createdAt = cal.date(byAdding: .day, value: -30, to: today)!
            ctx.insert(habit)
        }
        for offset in 0 ..< 7 {
            ctx.insert(HabitLog(date: cal.date(byAdding: .day, value: -offset, to: today)!, habit: h1))
        }
        for offset in 0 ..< 3 {
            ctx.insert(HabitLog(date: cal.date(byAdding: .day, value: -offset, to: today)!, habit: h2))
        }
        ctx.insert(HabitLog(date: today, habit: h3))
        // 5 записей в дневник со score 3..5
        let scores = [3, 4, 5, 4, 5]
        for (offset, score) in scores.enumerated() {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            ctx.insert(JournalEntry(date: day, moodScore: score))
        }
    }
}
