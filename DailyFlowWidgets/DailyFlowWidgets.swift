import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Entry

struct DailyFlowEntry: TimelineEntry {
    let date: Date
    let tasks: [DailyTask]
}

// MARK: - Provider

struct DailyFlowWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyFlowEntry {
        DailyFlowEntry(date: .now, tasks: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyFlowEntry) -> Void) {
        completion(DailyFlowEntry(date: .now, tasks: fetchTodayTasks()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyFlowEntry>) -> Void) {
        let tasks = fetchTodayTasks()
        let entry = DailyFlowEntry(date: .now, tasks: tasks)
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func fetchTodayTasks() -> [DailyTask] {
        guard let container = try? ModelContainer(
            for: DailyTask.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier("group.com.dmitry.dailyflow")
            )
        ) else { return [] }

        let ctx = ModelContext(container)
        let today = Calendar.current.startOfDay(for: .now)
        let pred = #Predicate<DailyTask> { $0.date == today }
        let descriptor = FetchDescriptor(predicate: pred, sortBy: [SortDescriptor(\.createdAt)])
        return (try? ctx.fetch(descriptor)) ?? []
    }
}

// MARK: - Widget colors (зеркало токенов — extension target не имеет доступа к модулю приложения)

private extension Color {
    static let wBgPrimary = Color(red: 0.051, green: 0.051, blue: 0.051)
    static let wAccentTeal = Color(red: 0.176, green: 0.831, blue: 0.627)
    static let wTextPrimary = Color(red: 0.949, green: 0.949, blue: 0.949)
    static let wTextSecondary = Color(red: 0.533, green: 0.533, blue: 0.533)
}

// MARK: - EntryView

struct DailyFlowWidgetEntryView: View {
    var entry: DailyFlowEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("СЕГОДНЯ")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Color.wTextSecondary)
                .tracking(0.5)

            if entry.tasks.isEmpty {
                Text("Нет задач")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.wTextSecondary)
            } else {
                ForEach(entry.tasks.prefix(5)) { task in
                    Button(intent: ToggleTaskIntent(taskID: task.id.uuidString)) {
                        HStack(spacing: 6) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(task.isCompleted ? Color.wAccentTeal : Color.wTextSecondary)
                            Text(task.title)
                                .font(.system(size: 12))
                                .foregroundStyle(task.isCompleted ? Color.wTextSecondary : Color.wTextPrimary)
                                .strikethrough(task.isCompleted)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.wBgPrimary)
    }
}

// MARK: - Widget

@main
struct DailyFlowWidget: Widget {
    let kind = "DailyFlowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyFlowWidgetProvider()) { entry in
            DailyFlowWidgetEntryView(entry: entry)
                .containerBackground(Color.wBgPrimary, for: .widget)
        }
        .configurationDisplayName("DailyFlow")
        .description("Задачи на сегодня")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
