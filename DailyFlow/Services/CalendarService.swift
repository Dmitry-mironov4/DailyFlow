import EventKit
import Foundation

enum CalendarService {
    static let store = EKEventStore()

    static func requestAccess() async -> Bool {
        await (try? store.requestWriteOnlyAccessToEvents()) ?? false
    }

    @discardableResult
    static func sync(_ task: DailyTask) -> String? {
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
        event.endDate = scheduledTime.addingTimeInterval(3600)
        event.calendar = store.defaultCalendarForNewEvents

        try? store.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    static func remove(eventID: String) {
        guard let event = store.event(withIdentifier: eventID) else { return }
        try? store.remove(event, span: .thisEvent)
    }
}
