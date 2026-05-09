import SwiftData
import SwiftUI

struct HabitsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    @State private var showAdd = false
    @State private var editingHabit: Habit?

    var body: some View {
        List {
            headerRow
            ForEach(habits) { habit in
                HabitCardView(
                    habit: habit,
                    onToggle: { HabitService.toggleToday(habit, in: ctx) },
                    onEdit: { editingHabit = habit },
                    onDelete: { HabitService.delete(habit, in: ctx) }
                )
                .listRowBackground(Color.bgPrimary)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onMove { HabitService.reorder(habits, from: $0, to: $1, in: ctx) }
            ghostAddRow
        }
        .listStyle(.plain)
        .background(Color.bgPrimary)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
        .sheet(isPresented: $showAdd) {
            AddHabitSheet(habit: nil) { name, hex in
                HabitService.add(name: name, colorHex: hex, in: ctx)
            }
        }
        .sheet(item: $editingHabit) { habit in
            AddHabitSheet(habit: habit) { name, hex in
                HabitService.update(habit, name: name, colorHex: hex, in: ctx)
            }
        }
    }

    private var headerRow: some View {
        Text("Привычки")
            .dfTitle()
            .listRowBackground(Color.bgPrimary)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
    }

    private var ghostAddRow: some View {
        Button { showAdd = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .foregroundStyle(Color.accentTeal)
                    .frame(width: 16, height: 16)
                Text("Добавить привычку")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.accentTeal)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.bgPrimary)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

#Preview("Пустой") {
    HabitsView()
        .modelContainer(.preview(.empty))
        .preferredColorScheme(.dark)
}

#Preview("Три привычки") {
    HabitsView()
        .modelContainer(.preview(.threeHabits))
        .preferredColorScheme(.dark)
}

#Preview("Все выполнены") {
    HabitsView()
        .modelContainer(.preview(.allHabitsDoneToday))
        .preferredColorScheme(.dark)
}

#Preview("Длинный стрик") {
    HabitsView()
        .modelContainer(.preview(.longStreak))
        .preferredColorScheme(.dark)
}
