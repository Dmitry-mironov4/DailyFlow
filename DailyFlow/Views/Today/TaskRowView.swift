import SwiftUI

struct CheckboxView: View {
    let isCompleted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .strokeBorder(isCompleted ? Color.clear : Color(hex: 0x333333), lineWidth: 1.5)
                    .background(
                        Circle().fill(isCompleted ? Color.accentTeal : Color.clear)
                    )
                    .frame(width: 15, height: 15)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(.circle)
        .animation(.easeInOut(duration: 0.15), value: isCompleted)
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

    @FocusState private var fieldFocused: Bool
    @State private var editBuffer = ""

    var body: some View {
        HStack(spacing: 8) {
            CheckboxView(isCompleted: task.isCompleted) {
                Haptics.tap(.medium)
                onToggle()
            }

            if isEditing {
                TextField("", text: $editBuffer)
                    .focused($fieldFocused)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)
                    .submitLabel(.done)
                    .onSubmit { onFinishEdit(editBuffer) }
                    .onAppear {
                        editBuffer = task.title
                        fieldFocused = true
                    }
            } else {
                Text(task.title)
                    .font(.system(size: 13))
                    .foregroundStyle(task.isCompleted ? Color.textSecondary : Color.textPrimary)
                    .strikethrough(task.isCompleted)
                    .opacity(task.isCompleted ? 0.5 : 1)
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.15), value: task.isCompleted)
            }

            Spacer()
        }
        .padding(.vertical, 10)
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
