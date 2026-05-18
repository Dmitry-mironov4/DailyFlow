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
                    .foregroundStyle(Color.textInverted.opacity(0.5))

                if isEditing {
                    TextField("", text: $editBuffer)
                        .focused($fieldFocused)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textInverted)
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
                            task.isCompleted
                                ? Color.textInverted.opacity(0.4)
                                : Color.textInverted
                        )
                        .strikethrough(task.isCompleted)
                        .lineLimit(2)
                }
            }

            Spacer()

            FocusCheckboxView(isCompleted: task.isCompleted, onTap: onToggle)
        }
        .dfAccentCard()
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

// MARK: — FocusCheckboxView

private struct FocusCheckboxView: View {
    let isCompleted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isCompleted ? Color.clear : Color.textInverted.opacity(0.3),
                        lineWidth: 1.5
                    )
                    .background(
                        Circle().fill(isCompleted ? Color.textInverted.opacity(0.2) : Color.clear)
                    )
                    .frame(width: 15, height: 15)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.textInverted)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(.circle)
        .animation(.easeInOut(duration: 0.15), value: isCompleted)
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
