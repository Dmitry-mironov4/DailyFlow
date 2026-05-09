import Foundation
import SwiftData

enum InsightsService {

    // MARK: — Окно

    /// Возвращает (start, end) окна [today−6 ... today], обе даты на startOfDay.
    private static func window(today: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: today)
        let start = cal.date(byAdding: .day, value: -6, to: end)!
        return (start, end)
    }

    // MARK: — tasksRate

    /// Доля выполненных задач за окно [today−6 ... today]. nil если задач 0.
    /// Возвращает значение в [0.0 ... 1.0].
    static func tasksRate(today: Date, in ctx: ModelContext) -> Double? {
        let (start, end) = window(today: today)
        let predicate = #Predicate<DailyTask> { $0.date >= start && $0.date <= end }
        guard let tasks = try? ctx.fetch(FetchDescriptor<DailyTask>(predicate: predicate)),
              !tasks.isEmpty else { return nil }
        let completed = tasks.lazy.filter(\.isCompleted).count
        return Double(completed) / Double(tasks.count)
    }
}
