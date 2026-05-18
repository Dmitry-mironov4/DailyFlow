import SwiftUI

struct AddTaskBarView: View {
    @Binding var text: String
    let onSubmit: (String, Int, Date?) -> Void
    @FocusState private var focused: Bool
    @State private var priority: Int = 0
    @State private var scheduledTime: Date?
    @State private var showTimePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: focused ? "circle.fill" : "plus")
                    .foregroundStyle(Color.accentWhite)
                    .frame(width: 16, height: 16)
                    .animation(.easeInOut(duration: 0.2), value: focused)

                TextField(focused ? "Новая задача…" : "Добавить задачу", text: $text)
                    .focused($focused)
                    .submitLabel(.return)
                    .onSubmit(submit)
                    .foregroundStyle(focused ? Color.textPrimary : Color.textGhost)
                    .font(.system(size: 13))
                    .tint(Color.accentWhite)

                if focused {
                    Button {
                        priority = (priority + 1) % 3
                        Haptics.tap(.light)
                    } label: {
                        Image(systemName: priority > 0 ? "circle.fill" : "circle")
                            .font(.system(size: 14))
                            .foregroundStyle(priorityColor)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))

                    Button {
                        showTimePicker.toggle()
                    } label: {
                        Image(systemName: scheduledTime != nil ? "clock.fill" : "clock")
                            .foregroundStyle(
                                scheduledTime != nil ? Color.accentWhite : Color.textSecondary
                            )
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                focused ? Color.bgElevated : Color.clear,
                in: .rect(cornerRadius: 8)
            )
            .overlay(alignment: .bottom) {
                if focused {
                    Rectangle()
                        .fill(Color.accentWhite)
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                }
            }

            if focused, showTimePicker {
                timePickerRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.25), value: showTimePicker)
        .animation(.easeInOut(duration: 0.2), value: focused)
        .contentShape(.rect)
        .onTapGesture { focused = true }
    }

    private var timePickerRow: some View {
        HStack {
            DatePicker(
                "",
                selection: Binding(
                    get: { scheduledTime ?? Date() },
                    set: { scheduledTime = $0 }
                ),
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(Color.accentWhite)

            if scheduledTime != nil {
                Button {
                    scheduledTime = nil
                    showTimePicker = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var priorityColor: Color {
        switch priority {
        case 1: Color.textPrimary
        case 2: Color.accentDestructive
        default: Color.textGhost
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Haptics.tap(.light)
        onSubmit(trimmed, priority, scheduledTime)
        text = ""
        priority = 0
        scheduledTime = nil
        showTimePicker = false
    }
}

#Preview {
    @Previewable @State var text = ""
    AddTaskBarView(text: $text, onSubmit: { _, _, _ in })
        .padding(.horizontal, 16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
