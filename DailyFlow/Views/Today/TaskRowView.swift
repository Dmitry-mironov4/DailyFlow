import SwiftUI

struct CheckboxView: View {
    let isCompleted: Bool
    let onTap: () -> Void

    @State private var justCompleted = false

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isCompleted ? Color.clear : Color.separator,
                        lineWidth: 1.5
                    )
                    .background(
                        Circle().fill(checkboxFill)
                    )
                    .frame(width: 15, height: 15)
                if isCompleted || justCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(checkmarkColor)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(.circle)
        .animation(.easeOut(duration: 0.15), value: isCompleted)
        .animation(.easeOut(duration: 0.15), value: justCompleted)
        .onChange(of: isCompleted) { _, newValue in
            if newValue {
                justCompleted = true
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    justCompleted = false
                }
            }
        }
    }

    private var checkboxFill: Color {
        if justCompleted { return Color.accentDone }
        if isCompleted { return Color.bgElevated }
        return .clear
    }

    private var checkmarkColor: Color {
        justCompleted ? .white : Color.textSecondary
    }

    private func handleTap() {
        onTap()
    }
}

struct TaskRowView: View {
    let task: DailyTask
    let isEditing: Bool
    let onToggle: () -> Void
    let onStartEdit: () -> Void
    let onFinishEdit: (String) -> Void
    let onSetFocus: () -> Void
    let onDelete: () -> Void
    var onSetPriority: ((Int) -> Void)?

    @FocusState private var fieldFocused: Bool
    @State private var editBuffer = ""

    var body: some View {
        HStack(spacing: 8) {
            if task.priority > 0 {
                Circle()
                    .fill(task.priority == 2 ? Color.accentDestructive : Color.textSecondary)
                    .frame(width: 6, height: 6)
                    .padding(.leading, 4)
            }
            CheckboxView(isCompleted: task.isCompleted) {
                Haptics.tap(.medium)
                onToggle()
            }

            if isEditing {
                TextField("", text: $editBuffer)
                    .focused($fieldFocused)
                    .dfBody()
                    .submitLabel(.done)
                    .onSubmit { onFinishEdit(editBuffer) }
                    .onAppear {
                        editBuffer = task.title
                        fieldFocused = true
                    }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .dfBody()
                        .foregroundStyle(
                            task.isCompleted
                                ? Color.textSecondary.opacity(0.5)
                                : Color.textPrimary
                        )
                        .strikethrough(task.isCompleted, color: Color.textSecondary)
                        .lineLimit(2)
                        .animation(.easeInOut(duration: 0.15), value: task.isCompleted)

                    if let time = task.scheduledTime {
                        Text(time, format: .dateTime.hour().minute())
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
        .contextMenu {
            Button {
                Haptics.tap(.medium)
                onSetFocus()
            } label: {
                Label(
                    task.isFocus ? "Снять с фокуса" : "Сделать фокусом",
                    systemImage: task.isFocus ? "star.slash" : "star"
                )
            }
            if let onSetPriority {
                Menu("Приоритет") {
                    Button("Срочная") { onSetPriority(2) }
                    Button("Важная") { onSetPriority(1) }
                    Button("Обычная") { onSetPriority(0) }
                }
            }
            Button { onStartEdit() } label: {
                Label("Изменить", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Haptics.tap(.heavy)
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Haptics.tap(.heavy)
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

#Preview {
    let task = DailyTask(title: "Написать тесты для TaskService", date: .now)
    VStack(spacing: 0) {
        TaskRowView(
            task: task,
            isEditing: false,
            onToggle: {},
            onStartEdit: {},
            onFinishEdit: { _ in },
            onSetFocus: {},
            onDelete: {}
        )
        Divider().background(Color.separator).padding(.leading, 52)
        let completed = DailyTask(title: "Завершённая задача", date: .now)
        TaskRowView(
            task: completed,
            isEditing: false,
            onToggle: {},
            onStartEdit: {},
            onFinishEdit: { _ in },
            onSetFocus: {},
            onDelete: {}
        )
    }
    .padding(.horizontal, 16)
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
