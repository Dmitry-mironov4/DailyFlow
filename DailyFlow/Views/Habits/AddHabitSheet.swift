import SwiftUI

struct AddHabitSheet: View {
    let habit: Habit?
    let onSave: (String, String, Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @FocusState private var isFocused: Bool

    init(habit: Habit?, onSave: @escaping (String, String, Date?) -> Void) {
        self.habit = habit
        self.onSave = onSave
        _name = State(initialValue: habit?.name ?? "")
        _reminderEnabled = State(initialValue: habit?.reminderTime != nil)
        _reminderTime = State(initialValue: habit?.reminderTime ?? defaultReminderTime())
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Название привычки", text: $name)
                    .dfBody()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.bgElevated, in: .rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.borderCard, lineWidth: 1)
                    )
                    .tint(Color.accentWhite)

                reminderRow

                Spacer()

                Button {
                    Haptics.tap(.light)
                    onSave(name, "808080", reminderEnabled ? reminderTime : nil)
                    dismiss()
                } label: {
                    Text(habit == nil ? "Добавить" : "Сохранить")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textInverted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentWhite, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgCard)
            .navigationTitle(habit == nil ? "Новая привычка" : "Изменить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgCard, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private var reminderRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $reminderEnabled.animation()) {
                Text("Напоминание")
                    .dfBody()
            }
            .tint(Color.accentWhite)

            if reminderEnabled {
                DatePicker("Время", selection: $reminderTime, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Color.accentWhite)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgElevated, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderCard, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: reminderEnabled)
    }
}

private func defaultReminderTime() -> Date {
    var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
    components.hour = 9
    components.minute = 0
    return Calendar.current.date(from: components) ?? .now
}

#Preview("Создание") {
    AddHabitSheet(habit: nil) { _, _, _ in }
        .preferredColorScheme(.dark)
}

#Preview("Редактирование") {
    AddHabitSheet(
        habit: Habit(name: "Медитация", colorHex: "808080", sortOrder: 0)
    ) { _, _, _ in }
        .preferredColorScheme(.dark)
}
