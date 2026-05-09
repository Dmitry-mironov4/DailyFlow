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

        // MARK: — setMood

        @Test func setMood_createsEntry_andSetsScore_whenAbsent() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            JournalService.setMood(4, in: ctx)
            let entry = JournalService.entryForToday(in: ctx)
            #expect(entry?.moodScore == 4)
        }

        @Test func setMood_updatesScore_whenEntryExists() async throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            let originalUpdatedAt = entry.updatedAt
            try await Task.sleep(for: .milliseconds(10))
            JournalService.setMood(5, in: ctx)
            #expect(entry.moodScore == 5)
            #expect(entry.updatedAt > originalUpdatedAt)
        }

        @Test func setMood_isNoOp_whenSameScore() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            entry.moodScore = 3
            entry.updatedAt = Date(timeIntervalSince1970: 1_000_000)
            try ctx.save()
            JournalService.setMood(3, in: ctx)
            #expect(entry.moodScore == 3)
            #expect(entry.updatedAt == Date(timeIntervalSince1970: 1_000_000))
        }

        @Test func setMood_acceptsBoundaryValues() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            JournalService.setMood(1, in: ctx)
            #expect(JournalService.entryForToday(in: ctx)?.moodScore == 1)
            JournalService.setMood(5, in: ctx)
            #expect(JournalService.entryForToday(in: ctx)?.moodScore == 5)
        }

        // MARK: — setText

        @Test func setText_createsEntry_whenTextNonEmpty_andAbsent() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            JournalService.setText("hello", in: ctx)
            let entry = JournalService.entryForToday(in: ctx)
            #expect(entry?.text == "hello")
            #expect(entry?.moodScore == 3)
        }

        @Test func setText_doesNotCreateEntry_whenTextEmpty_andAbsent() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            JournalService.setText("", in: ctx)
            #expect(JournalService.entryForToday(in: ctx) == nil)
        }

        @Test func setText_updatesText_whenEntryExists() async throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            let originalUpdatedAt = entry.updatedAt
            try await Task.sleep(for: .milliseconds(10))
            JournalService.setText("new text", in: ctx)
            #expect(entry.text == "new text")
            #expect(entry.moodScore == 3)
            #expect(entry.updatedAt > originalUpdatedAt)
        }

        @Test func setText_acceptsEmptyString_whenEntryExists() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            entry.text = "previous"
            try ctx.save()
            JournalService.setText("", in: ctx)
            #expect(entry.text == "")
        }

        @Test func setText_isNoOp_whenSameValue() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            entry.text = "stable"
            entry.updatedAt = Date(timeIntervalSince1970: 1_000_000)
            try ctx.save()
            JournalService.setText("stable", in: ctx)
            #expect(entry.text == "stable")
            #expect(entry.updatedAt == Date(timeIntervalSince1970: 1_000_000))
        }
    }
}
