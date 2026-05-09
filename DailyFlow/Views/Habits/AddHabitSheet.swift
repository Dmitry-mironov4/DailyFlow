import SwiftUI

struct AddHabitSheet: View {
    let habit: Habit?
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedHex: String
    @FocusState private var isFocused: Bool

    private let colorOptions = ["2DD4A0", "F0A23B", "9B8AE8"]

    init(habit: Habit?, onSave: @escaping (String, String) -> Void) {
        self.habit = habit
        self.onSave = onSave
        _name = State(initialValue: habit?.name ?? "")
        _selectedHex = State(initialValue: habit?.colorHex ?? "2DD4A0")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 32) {
                TextField("Название привычки", text: $name)
                    .dfBody()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.bgCard, in: .rect(cornerRadius: 12))

                HStack(spacing: 12) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Button {
                            selectedHex = hex
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 32, height: 32)
                                    .opacity(selectedHex == hex ? 1.0 : 0.4)
                                if selectedHex == hex {
                                    Circle()
                                        .strokeBorder(Color(hex: hex), lineWidth: 2)
                                        .frame(width: 40, height: 40)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgPrimary)
            .navigationTitle(habit == nil ? "Новая привычка" : "Изменить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(habit == nil ? "Добавить" : "Сохранить") {
                        Haptics.tap(.light)
                        onSave(name, selectedHex)
                        dismiss()
                    }
                    .foregroundStyle(Color.accentTeal)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

#Preview("Создание") {
    AddHabitSheet(habit: nil) { _, _ in }
        .preferredColorScheme(.dark)
}

#Preview("Редактирование") {
    AddHabitSheet(
        habit: Habit(name: "Медитация", colorHex: "F0A23B", sortOrder: 0)
    ) { _, _ in }
        .preferredColorScheme(.dark)
}
