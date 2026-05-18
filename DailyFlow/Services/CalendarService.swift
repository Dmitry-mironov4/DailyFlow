import EventKit
import Foundation
import OSLog

private nonisolated(unsafe) let logger = Logger(subsystem: "com.dmitry.DailyFlow", category: "CalendarService")

enum CalendarService {
    static let store = EKEventStore()

    static func requestAccess() async -> Bool {
        await (try? store.requestWriteOnlyAccessToEvents()) ?? false
    }

    @discardableResult
    static func sync(_ task: DailyTask, duration: TimeInterval = 3600) -> String? {
        guard let scheduledTime = task.scheduledTime else { return nil }

        let event: EKEvent
        if let existingID = task.calendarEventID,
           let existing = store.event(withIdentifier: existingID) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
        }

        event.title = task.title
        event.startDate = scheduledTime
        event.endDate = scheduledTime.addingTimeInterval(duration)
        event.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(event, span: .thisEvent)
        } catch {
            logger.error("sync save: \(error.localizedDescription)")
            return nil
        }
        return event.eventIdentifier
    }

    static func remove(eventID: String) {
        guard let event = store.event(withIdentifier: eventID) else { return }
        do {
            try store.remove(event, span: .thisEvent)
        } catch {
            logger.error("remove: \(error.localizedDescription)")
        }
    }
}
