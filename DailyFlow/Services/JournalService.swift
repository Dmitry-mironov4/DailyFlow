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

    /// Устанавливает moodScore.
    /// Если значение совпадает с текущим — no-op (updatedAt не меняется).
    /// Если записи нет — создаёт через getOrCreateToday и сразу выставляет.
    static func setMood(_ score: Int, in ctx: ModelContext, now: Date = .now) {
        precondition((1...5).contains(score), "moodScore must be in 1...5")
        let entry = getOrCreateToday(in: ctx, now: now)
        guard entry.moodScore != score else { return }
        entry.moodScore = score
        entry.updatedAt = now
        try? ctx.save()
    }

    /// Записывает text.
    /// Если запись отсутствует и text пустой — no-op (не плодим пустые записи).
    /// Если запись отсутствует и text не пустой — создаёт через getOrCreateToday и пишет text.
    /// Обновляет updatedAt только если значение реально изменилось.
    static func setText(_ text: String, in ctx: ModelContext, now: Date = .now) {
        if entryForToday(in: ctx, now: now) == nil, text.isEmpty {
            return
        }
        let entry = getOrCreateToday(in: ctx, now: now)
        guard entry.text != text else { return }
        entry.text = text
        entry.updatedAt = now
        try? ctx.save()
    }
}
