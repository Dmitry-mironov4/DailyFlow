import SwiftData
import SwiftUI

struct HabitCardView: View {
    let habit: Habit
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var isDoneToday: Bool {
        HabitService.isDone(habit, on: .now)
    }

    private var streakResult: (value: Int, isActive: Bool) {
        HabitService.streak(for: habit, relativeTo: .now)
    }

    private var accentColor: Color {
        Color(hex: habit.colorHex)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(habit.name).dfBody()
                PixelGridView(habit: habit)
            }
            Spacer()
            Text("\(streakResult.value)")
                .font(.system(size: 21, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(streakResult.isActive ? accentColor : Color.textSecondary)
                .animation(.easeInOut(duration: 0.2), value: streakResult.isActive)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            isDoneToday ? accentColor.opacity(0.08) : Color.bgCard,
            in: .rect(cornerRadius: 12)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 4)
                .opacity(isDoneToday ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isDoneToday)
        }
        .animation(.easeInOut(duration: 0.2), value: isDoneToday)
        .contentShape(.rect)
        .onTapGesture {
            let wasActive = isDoneToday
            onToggle()
            Haptics.tap(wasActive ? .light : .medium)
        }
        .contextMenu {
            Button("Изменить") { onEdit() }
            Button("Удалить", role: .destructive) {
                Haptics.tap(.heavy)
                onDelete()
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

#Preview("Не выполнена") {
    let habit = Habit(name: "Медитация", colorHex: "2DD4A0", sortOrder: 0)
    return HabitCardView(habit: habit, onToggle: {}, onEdit: {}, onDelete: {})
        .padding()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}

#Preview("Выполнена сегодня") {
    let container = ModelContainer.preview(.empty)
    let habit = Habit(name: "Спорт", colorHex: "F0A23B", sortOrder: 0)
    let today = Calendar.current.startOfDay(for: .now)
    container.mainContext.insert(habit)
    container.mainContext.insert(HabitLog(date: today, habit: habit))
    return HabitCardView(habit: habit, onToggle: {}, onEdit: {}, onDelete: {})
        .padding()
        .background(Color.bgPrimary)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
