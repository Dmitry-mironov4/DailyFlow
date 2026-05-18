import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Entry

struct DailyFlowEntry: TimelineEntry {
    let date: Date
    let tasks: [DailyTask]

    var completedCount: Int {
        tasks.filter(\.isCompleted).count
    }

    var totalCount: Int {
        tasks.count
    }
}

// MARK: - Provider

struct DailyFlowWidgetProvider: TimelineProvider {
    func placeholder(in _: Context) -> DailyFlowEntry {
        DailyFlowEntry(date: .now, tasks: [])
    }

    func getSnapshot(in _: Context, completion: @escaping (DailyFlowEntry) -> Void) {
        completion(DailyFlowEntry(date: .now, tasks: fetchTodayTasks()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<DailyFlowEntry>) -> Void) {
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
    static let wBgPrimary = Color(red: 0.067, green: 0.071, blue: 0.078) // 0x111214
    static let wBgCard = Color(red: 0.102, green: 0.110, blue: 0.122) // 0x1A1C1F
    static let wAccent = Color(red: 0.961, green: 0.961, blue: 0.961) // 0xF5F5F5
    static let wTextPrim = Color(red: 0.863, green: 0.863, blue: 0.863) // 0xDCDCDC
    static let wTextSec = Color(red: 0.502, green: 0.502, blue: 0.502) // 0x808080
    static let wDone = Color(red: 0.290, green: 0.871, blue: 0.502) // 0x4ADE80
}

// MARK: - Home Screen EntryView

struct DailyFlowWidgetEntryView: View {
    var entry: DailyFlowEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("СЕГОДНЯ")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Color.wTextSec)
                .tracking(0.5)

            if entry.tasks.isEmpty {
                Text("Нет задач")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.wTextSec)
            } else {
                ForEach(entry.tasks.prefix(5)) { task in
                    Button(intent: ToggleTaskIntent(taskID: task.id.uuidString)) {
                        HStack(spacing: 6) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(task.isCompleted ? Color.wDone : Color.wTextSec)
                            Text(task.title)
                                .font(.system(size: 12))
                                .foregroundStyle(task.isCompleted ? Color.wTextSec : Color.wTextPrim)
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

// MARK: - Lock Screen EntryView

struct LockScreenWidgetView: View {
    var entry: DailyFlowEntry

    var body: some View {
        Gauge(
            value: Double(entry.completedCount),
            in: 0 ... Double(max(entry.totalCount, 1))
        ) {
            Image(systemName: "checkmark")
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Color.wAccent)
    }
}

// MARK: - Home Screen Widget

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

// MARK: - Lock Screen Widget

struct LockScreenWidget: Widget {
    let kind = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyFlowWidgetProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("DailyFlow — Экран блокировки")
        .description("Прогресс задач дня")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Widget Bundle

@main
struct DailyFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyFlowWidget()
        LockScreenWidget()
    }
}
