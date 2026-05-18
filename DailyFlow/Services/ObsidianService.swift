import Foundation
import OSLog
import SwiftUI
import UIKit

private nonisolated(unsafe) let logger = Logger(subsystem: "com.dmitry.DailyFlow", category: "ObsidianService")

enum ObsidianService {
    // MARK: — Export Day

    static func exportDay(
        date: Date,
        tasks: [DailyTask],
        habits: [Habit],
        logs: [HabitLog],
        entry: JournalEntry?
    ) {
        let markdown = buildDayMarkdown(date: date, tasks: tasks, habits: habits, logs: logs, entry: entry)
        let filename = dayFilename(for: date)
        presentPicker(content: markdown, filename: filename)
    }

    // MARK: — Export Full Backup

    static func exportFullBackup(
        tasks: [DailyTask],
        habits: [Habit],
        logs: [HabitLog],
        entries: [JournalEntry]
    ) {
        let payload: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: .now),
            "tasks": tasks.map { taskDict($0) },
            "habits": habits.map { habitDict($0) },
            "habitLogs": logs.map { logDict($0) },
            "journalEntries": entries.map { entryDict($0) },
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8)
        else {
            logger.error("exportFullBackup: JSON serialization failed")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "dailyflow-backup-\(formatter.string(from: .now)).json"
        presentPicker(content: json, filename: filename)
    }

    // MARK: — Markdown builder

    private static func buildDayMarkdown(
        date: Date,
        tasks: [DailyTask],
        habits: [Habit],
        logs: [HabitLog],
        entry: JournalEntry?
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        var lines: [String] = ["# \(dateStr)", ""]

        // Задачи
        lines.append("## Задачи")
        let focus = tasks.first { $0.isFocus }
        let regular = tasks.filter { !$0.isFocus }

        if let focus {
            let mark = focus.isCompleted ? "x" : " "
            lines.append("- [\(mark)] ⭐ \(focus.title)")
        }
        for task in regular {
            let mark = task.isCompleted ? "x" : " "
            lines.append("- [\(mark)] \(task.title)")
        }
        if tasks.isEmpty { lines.append("_Нет задач_") }
        lines.append("")

        // Привычки
        lines.append("## Привычки")
        let logDates = Set(logs.map(\.date))
        let today = Calendar.current.startOfDay(for: date)
        for habit in habits {
            let done = logs.contains { $0.date == today && $0.habit?.id == habit.id }
            lines.append("- \(done ? "✓" : "✗") \(habit.name)")
        }
        if habits.isEmpty { lines.append("_Нет привычек_") }
        lines.append("")

        // Настроение и текст
        if let entry {
            lines.append("## Настроение: \(entry.moodScore)/5")
            if !entry.text.isEmpty {
                lines.append(entry.text)
            }
        }

        _ = logDates // suppress unused warning
        return lines.joined(separator: "\n")
    }

    // MARK: — JSON helpers

    private static func taskDict(_ task: DailyTask) -> [String: Any] {
        var dict: [String: Any] = [
            "id": task.id.uuidString,
            "title": task.title,
            "isFocus": task.isFocus,
            "isCompleted": task.isCompleted,
            "date": ISO8601DateFormatter().string(from: task.date),
            "createdAt": ISO8601DateFormatter().string(from: task.createdAt),
            "priority": task.priority,
        ]
        if let completedAt = task.completedAt {
            dict["completedAt"] = ISO8601DateFormatter().string(from: completedAt)
        }
        return dict
    }

    private static func habitDict(_ habit: Habit) -> [String: Any] {
        [
            "id": habit.id.uuidString,
            "name": habit.name,
            "createdAt": ISO8601DateFormatter().string(from: habit.createdAt),
        ]
    }

    private static func logDict(_ log: HabitLog) -> [String: Any] {
        [
            "id": log.id.uuidString,
            "date": ISO8601DateFormatter().string(from: log.date),
            "habitId": log.habit?.id.uuidString ?? "",
        ]
    }

    private static func entryDict(_ entry: JournalEntry) -> [String: Any] {
        [
            "id": entry.id.uuidString,
            "date": ISO8601DateFormatter().string(from: entry.date),
            "moodScore": entry.moodScore,
            "text": entry.text,
        ]
    }

    // MARK: — File picker

    private static func presentPicker(content: String, filename: String) {
        guard let data = content.data(using: .utf8) else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: tempURL)
        } catch {
            logger.error("presentPicker write: \(error.localizedDescription)")
            return
        }

        let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        root.present(picker, animated: true)
    }

    private static func dayFilename(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "\(fmt.string(from: date)).md"
    }
}
