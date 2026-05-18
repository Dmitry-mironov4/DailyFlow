import SwiftData
import SwiftUI

struct HabitCardView: View {
    let habit: Habit
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onShowDetail: () -> Void

    private var isDoneToday: Bool {
        HabitService.isDone(habit, on: .now)
    }

    private var streakResult: (value: Int, isActive: Bool) {
        HabitService.streak(for: habit, relativeTo: .now)
    }

    var body: some View {
        HStack(spacing: 14) {
            HabitToggleRing(isDone: isDoneToday)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 6) {
                Text(habit.name).dfBody()
                WeekDotsRow(habit: habit)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(streakResult.value)")
                    .font(.system(size: 18, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(streakResult.isActive ? Color.textPrimary : Color.textSecondary)
                Text("\(streakResult.value == 1 ? "день" : "дн.")")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            isDoneToday ? Color.bgElevated : Color.bgCard,
            in: .rect(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isDoneToday ? Color.accentDone.opacity(0.25) : Color.borderCard,
                    lineWidth: 1
                )
        )
        .contentShape(.rect)
        .onTapGesture {
            let wasActive = isDoneToday
            onToggle()
            Haptics.tap(wasActive ? .light : .medium)
        }
        .onLongPressGesture {
            Haptics.tap(.medium)
            onShowDetail()
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

// MARK: — HabitToggleRing

private struct HabitToggleRing: View {
    let isDone: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Color.separator, lineWidth: 2)
            Circle()
                .trim(from: 0, to: isDone ? 1 : 0)
                .stroke(
                    isDone ? Color.accentDone : Color.clear,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.65), value: isDone)
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accentDone)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isDone)
    }
}

// MARK: — WeekDotsRow

struct WeekDotsRow: View {
    let habit: Habit

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0 ..< 7).map { cal.date(byAdding: .day, value: $0 - 6, to: today)! }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                let isDone = HabitService.isDone(habit, on: day)
                let size: CGFloat = isToday ? 7 : 6

                ZStack {
                    Circle()
                        .fill(isDone ? Color.accentWhite.opacity(0.9) : Color.bgElevated)
                        .frame(width: size, height: size)
                    if isToday, !isDone {
                        Circle()
                            .strokeBorder(Color.textSecondary.opacity(0.4), lineWidth: 1)
                            .frame(width: size, height: size)
                    }
                }
            }
        }
    }
}

// MARK: — Previews

#Preview("Не выполнена") {
    let habit = Habit(name: "Медитация", colorHex: "808080", sortOrder: 0)
    return HabitCardView(habit: habit, onToggle: {}, onEdit: {}, onDelete: {}, onShowDetail: {})
        .padding()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}

#Preview("Выполнена сегодня") {
    let container = ModelContainer.preview(.empty)
    let habit = Habit(name: "Спорт", colorHex: "808080", sortOrder: 0)
    let today = Calendar.current.startOfDay(for: .now)
    container.mainContext.insert(habit)
    container.mainContext.insert(HabitLog(date: today, habit: habit))
    return HabitCardView(habit: habit, onToggle: {}, onEdit: {}, onDelete: {}, onShowDetail: {})
        .padding()
        .background(Color.bgPrimary)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
