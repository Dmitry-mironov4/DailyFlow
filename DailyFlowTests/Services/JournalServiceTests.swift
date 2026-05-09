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
    }
}
