import SwiftUI

struct FocusCardView: View {
    let task: DailyTask
    let isEditing: Bool
    let onToggle: () -> Void
    let onStartEdit: () -> Void
    let onFinishEdit: (String) -> Void
    let onClearFocus: () -> Void
    let onDelete: () -> Void

    @FocusState private var fieldFocused: Bool
    @State private var editBuffer = ""

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ФОКУС")
                    .font(.system(size: 10))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.accentTeal)

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
                        .foregroundStyle(
                            task.isCompleted ? Color.textSecondary : Color.textPrimary
                        )
                        .strikethrough(task.isCompleted)
                        .opacity(task.isCompleted ? 0.5 : 1)
                        .lineLimit(2)
                }
            }

            Spacer()

            CheckboxView(isCompleted: task.isCompleted, onTap: onToggle)
        }
        .dfAccentCard(color: .accentTeal)
        .animation(.easeInOut(duration: 0.15), value: task.isCompleted)
        .contextMenu {
            Button {
                Haptics.tap(.medium)
                onClearFocus()
            } label: {
                Label("Снять с фокуса", systemImage: "star.slash")
            }
            Button {
                onStartEdit()
            } label: {
                Label("Изменить", systemImage: "pencil")
            }
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
    let task = DailyTask(title: "Завершить архитектуру экрана Сегодня", date: .now, isFocus: true)
    FocusCardView(
        task: task,
        isEditing: false,
        onToggle: {},
        onStartEdit: {},
        onFinishEdit: { _ in },
        onClearFocus: {},
        onDelete: {}
    )
    .padding(.horizontal, 16)
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
