import SwiftUI

struct AddTaskBarView: View {
    @Binding var text: String
    let onSubmit: (String, Date?) -> Void
    @FocusState private var focused: Bool
    @State private var scheduledTime: Date?
    @State private var showTimePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: focused ? "circle.fill" : "plus")
                    .foregroundStyle(Color.accentTeal)
                    .frame(width: 16, height: 16)
                    .animation(.easeInOut(duration: 0.2), value: focused)

                TextField(focused ? "Новая задача…" : "Добавить задачу", text: $text)
                    .focused($focused)
                    .submitLabel(.return)
                    .onSubmit(submit)
                    .foregroundStyle(focused ? Color.textPrimary : Color.textGhost)
                    .font(.system(size: 13))

                if focused {
                    Button {
                        showTimePicker.toggle()
                    } label: {
                        Image(systemName: scheduledTime != nil ? "clock.fill" : "clock")
                            .foregroundStyle(scheduledTime != nil ? Color.accentTeal : Color.textSecondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                if focused {
                    Rectangle()
                        .fill(Color.accentTeal)
                        .frame(height: 1)
                }
            }

            if focused && showTimePicker {
                timePickerRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(.rect)
        .onTapGesture { focused = true }
        .animation(.spring(duration: 0.25), value: showTimePicker)
        .animation(.easeInOut(duration: 0.2), value: focused)
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
            .accentColor(Color.accentTeal)

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
        .padding(.vertical, 8)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Haptics.tap(.light)
        onSubmit(trimmed, scheduledTime)
        text = ""
        scheduledTime = nil
        showTimePicker = false
    }
}

#Preview {
    @Previewable @State var text = ""
    AddTaskBarView(text: $text, onSubmit: { _, _ in })
        .padding(.horizontal, 16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
