import AppIntents
import OSLog
import SwiftData
import WidgetKit

private nonisolated(unsafe) let logger = Logger(subsystem: "com.dmitry.DailyFlow.Widgets", category: "ToggleTaskIntent")

struct ToggleTaskIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Toggle Task"

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        let config = ModelConfiguration(
            groupContainer: .identifier("group.com.dmitry.dailyflow")
        )
        let container = try ModelContainer(for: DailyTask.self, configurations: config)
        let ctx = ModelContext(container)

        guard let targetID = UUID(uuidString: taskID) else {
            return .result()
        }
        let pred = #Predicate<DailyTask> { $0.id == targetID }
        do {
            if let task = try ctx.fetch(FetchDescriptor(predicate: pred)).first {
                task.isCompleted.toggle()
                task.completedAt = task.isCompleted ? .now : nil
                try ctx.save()
            }
        } catch {
            logger.error("perform: \(error.localizedDescription)")
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
