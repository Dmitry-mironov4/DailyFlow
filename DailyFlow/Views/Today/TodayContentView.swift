import SwiftData
import SwiftUI

struct TodayContentView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    @Query private var todayTasks: [DailyTask]
    @Query private var pendingFromPast: [DailyTask]

    @State private var addBarText = ""
    @State private var editingTaskId: UUID?

    private let dateAnchor: Date

    init(dateAnchor: Date) {
        self.dateAnchor = dateAnchor
        let today = dateAnchor
        _todayTasks = Query(
            filter: #Predicate<DailyTask> { $0.date == today },
            sort: [SortDescriptor(\.createdAt, order: .forward)]
        )
        _pendingFromPast = Query(
            filter: #Predicate<DailyTask> { $0.date < today && $0.isCompleted == false }
        )
    }

    private var focus: DailyTask? {
        todayTasks.first { $0.isFocus }
    }

    private var regular: [DailyTask] {
        todayTasks.filter { !$0.isFocus }
    }

    private var completedCount: Int {
        todayTasks.filter(\.isCompleted).count
    }

    private var totalCount: Int {
        todayTasks.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerView

                if !pendingFromPast.isEmpty {
                    RolloverBannerView(
                        count: pendingFromPast.count,
                        onMove: { _ = try? TaskService.rolloverPending(into: dateAnchor, in: ctx) },
                        onDiscard: { _ = try? TaskService.discardPending(before: dateAnchor, in: ctx) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let focus {
                    FocusCardView(
                        task: focus,
                        isEditing: editingTaskId == focus.id,
                        onToggle: { TaskService.toggleCompletion(focus, in: ctx) },
                        onStartEdit: { editingTaskId = focus.id },
                        onFinishEdit: { commitEdit(focus, $0) },
                        onClearFocus: { try? TaskService.clearFocus(on: dateAnchor, in: ctx) },
                        onDelete: { TaskService.delete(focus, in: ctx) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !todayTasks.isEmpty {
                    Text("ЗАДАЧИ — \(completedCount)/\(totalCount)")
                        .dfCaption()
                }

                if !regular.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(regular) { task in
                            TaskRowView(
                                task: task,
                                isEditing: editingTaskId == task.id,
                                onToggle: { TaskService.toggleCompletion(task, in: ctx) },
                                onStartEdit: { editingTaskId = task.id },
                                onFinishEdit: { commitEdit(task, $0) },
                                onSetFocus: { try? TaskService.setFocus(task, in: ctx) },
                                onDelete: { TaskService.delete(task, in: ctx) }
                            )
                        }
                    }
                    .dfCard()
                }

                AddTaskBarView(
                    text: $addBarText,
                    onSubmit: { TaskService.add(title: $0, on: dateAnchor, in: ctx) }
                )
            }
            .padding(.horizontal, 16)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: focus?.id)
        }
        .background(Color.bgPrimary)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background, editingTaskId != nil else { return }
            editingTaskId = nil
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateCaption)
                .dfCaption()
            Text("Сегодня")
                .dfTitle()
        }
        .padding(.bottom, 14)
    }

    private var dateCaption: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "EEEE, d MMMM"
        return fmt.string(from: dateAnchor).uppercased()
    }

    private func commitEdit(_ task: DailyTask, _ newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != task.title {
            TaskService.updateTitle(task, to: trimmed, in: ctx)
            Haptics.tap(.light)
        }
        editingTaskId = nil
    }
}

#Preview("Empty") {
    TodayContentView(dateAnchor: .now)
        .modelContainer(ModelContainer.preview(.empty))
        .preferredColorScheme(.dark)
}

#Preview("Only focus") {
    TodayContentView(dateAnchor: .now)
        .modelContainer(ModelContainer.preview(.onlyFocus))
        .preferredColorScheme(.dark)
}

#Preview("Mixed") {
    TodayContentView(dateAnchor: .now)
        .modelContainer(ModelContainer.preview(.mixed))
        .preferredColorScheme(.dark)
}

#Preview("With banner") {
    TodayContentView(dateAnchor: .now)
        .modelContainer(ModelContainer.preview(.withRollover))
        .preferredColorScheme(.dark)
}

#Preview("Edit mode") {
    TodayContentView(dateAnchor: .now)
        .modelContainer(ModelContainer.preview(.editingFirst))
        .preferredColorScheme(.dark)
}
