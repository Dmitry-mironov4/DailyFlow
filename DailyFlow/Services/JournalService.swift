import Foundation
import OSLog
import SwiftData

private nonisolated(unsafe) let logger = Logger(subsystem: "com.dmitry.DailyFlow", category: "JournalService")

enum JournalService {
    static func entryForToday(in ctx: ModelContext, now: Date = .now) -> JournalEntry? {
        let target = Calendar.current.startOfDay(for: now)
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.date == target }
        )
        do { return try ctx.fetch(descriptor).first } catch {
            logger.error("entryForToday fetch: \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    static func getOrCreateToday(in ctx: ModelContext, now: Date = .now) -> JournalEntry {
        if let existing = entryForToday(in: ctx, now: now) { return existing }
        let entry = JournalEntry(date: now)
        ctx.insert(entry)
        do { try ctx.save() } catch { logger.error("getOrCreateToday save: \(error.localizedDescription)") }
        return entry
    }

    static func setMood(_ score: Int, in ctx: ModelContext, now: Date = .now) {
        guard (1 ... 5).contains(score) else { return }
        let entry = getOrCreateToday(in: ctx, now: now)
        guard entry.moodScore != score else { return }
        entry.moodScore = score
        entry.updatedAt = now
        do { try ctx.save() } catch { logger.error("setMood save: \(error.localizedDescription)") }
    }

    static func setActivities(_ activities: [String], in ctx: ModelContext, now: Date = .now) {
        let entry = getOrCreateToday(in: ctx, now: now)
        guard entry.activities != activities else { return }
        entry.activities = activities
        entry.updatedAt = now
        do { try ctx.save() } catch { logger.error("setActivities save: \(error.localizedDescription)") }
    }

    static func setText(_ text: String, in ctx: ModelContext, now: Date = .now) {
        if entryForToday(in: ctx, now: now) == nil, text.isEmpty { return }
        let entry = getOrCreateToday(in: ctx, now: now)
        guard entry.text != text else { return }
        entry.text = text
        entry.updatedAt = now
        do { try ctx.save() } catch { logger.error("setText save: \(error.localizedDescription)") }
    }
}
