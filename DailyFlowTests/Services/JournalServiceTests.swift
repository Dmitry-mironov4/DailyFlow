import Foundation
import SwiftData
import Testing
@testable import DailyFlow

extension DailyFlowTests {
    @Suite("JournalService", .serialized) @MainActor
    struct JournalServiceTests {

        // MARK: — entryForToday

        @Test func entryForToday_returnsNil_whenNoEntry() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            #expect(JournalService.entryForToday(in: ctx) == nil)
        }

        @Test func entryForToday_returnsEntry_whenExistsForToday() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalEntry(date: .now, moodScore: 4, text: "test")
            ctx.insert(entry)
            try ctx.save()
            #expect(JournalService.entryForToday(in: ctx)?.id == entry.id)
        }

        @Test func entryForToday_returnsNil_whenEntryIsForYesterday() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
            let entry = JournalEntry(date: yesterday, moodScore: 3, text: "")
            ctx.insert(entry)
            try ctx.save()
            #expect(JournalService.entryForToday(in: ctx) == nil)
        }

        // MARK: — getOrCreateToday

        @Test func getOrCreateToday_createsWithDefaults_whenAbsent() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            #expect(entry.moodScore == 3)
            #expect(entry.text == "")
            #expect(entry.date == Calendar.current.startOfDay(for: .now))
        }

        @Test func getOrCreateToday_returnsExisting_andDoesNotDuplicate() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let first = JournalService.getOrCreateToday(in: ctx)
            let second = JournalService.getOrCreateToday(in: ctx)
            #expect(first.id == second.id)
            let all = (try? ctx.fetch(FetchDescriptor<JournalEntry>())) ?? []
            #expect(all.count == 1)
        }

        @Test func getOrCreateToday_dateIsAlwaysStartOfDay() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            // Симулируем «полдень» как now
            var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
            components.hour = 13
            components.minute = 27
            let noon = Calendar.current.date(from: components)!
            let entry = JournalService.getOrCreateToday(in: ctx, now: noon)
            #expect(entry.date == Calendar.current.startOfDay(for: noon))
        }
    }
}
