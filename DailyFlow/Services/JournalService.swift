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
}
