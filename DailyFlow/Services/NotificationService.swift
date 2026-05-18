import Foundation
import OSLog
import UserNotifications

private nonisolated(unsafe) let logger = Logger(subsystem: "com.dmitry.DailyFlow", category: "NotificationService")

enum NotificationService {
    static func requestPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                logger.info("Notification permission granted: \(granted)")
            } catch {
                logger.error("requestPermission: \(error.localizedDescription)")
            }
        }
    }

    static func scheduleHabitReminder(for habit: Habit, at time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Привычка"
        content.body = habit.name
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "habit-\(habit.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { logger.error("scheduleHabitReminder: \(error.localizedDescription)") }
        }
    }

    static func cancelReminder(for habit: Habit) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["habit-\(habit.id)"])
    }

    static func scheduleDailySummary(at time: Date, completedCount: Int, totalCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Итоги дня"
        content.body = "Сегодня выполнено \(completedCount) из \(totalCount) задач"
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-summary",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { logger.error("scheduleDailySummary: \(error.localizedDescription)") }
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
