import AppIntents
import SwiftData
import WidgetKit

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
        if let task = try ctx.fetch(FetchDescriptor(predicate: pred)).first {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? .now : nil
            try ctx.save()
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
