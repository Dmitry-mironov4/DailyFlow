import Foundation
import SwiftData

enum JournalService {

    /// Возвращает запись за сегодня (по startOfDay) или nil если её нет.
    static func entryForToday(in ctx: ModelContext, now: Date = .now) -> JournalEntry? {
        let target = Calendar.current.startOfDay(for: now)
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.date == target }
        )
        return (try? ctx.fetch(descriptor))?.first
    }

    /// Возвращает существующую запись или создаёт новую с дефолтами и инсертит в контекст.
    /// Дефолты: moodScore = 3, text = "".
    @discardableResult
    static func getOrCreateToday(in ctx: ModelContext, now: Date = .now) -> JournalEntry {
        if let existing = entryForToday(in: ctx, now: now) {
            return existing
        }
        let entry = JournalEntry(date: now)
        ctx.insert(entry)
        try? ctx.save()
        return entry
    }
}
