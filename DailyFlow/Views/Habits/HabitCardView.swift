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

    private var accentColor: Color {
        Color(hex: habit.colorHex)
    }

    var body: some View {
        HStack(spacing: 14) {
            CircularProgressRing(isDone: isDoneToday, color: accentColor)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 6) {
                Text(habit.name).dfBody()
                WeekDotsRow(habit: habit)
            }

            Spacer()

            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(streakResult.isActive ? accentColor : Color.textGhost)
                Text("\(streakResult.value)")
                    .font(.system(size: 18, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(streakResult.isActive ? accentColor : Color.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            isDoneToday ? accentColor.opacity(0.08) : Color.bgCard,
            in: .rect(cornerRadius: 14)
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

// MARK: — CircularProgressRing

struct CircularProgressRing: View {
    let isDone: Bool
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: isDone ? 1 : 0)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.65), value: isDone)
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
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

    private var accentColor: Color { Color(hex: habit.colorHex) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                let isDone = HabitService.isDone(habit, on: day)
                let size: CGFloat = isToday ? 7 : 6

                ZStack {
                    Circle()
                        .fill(isDone ? accentColor : Color.bgPixelInactive)
                        .frame(width: size, height: size)
                    if isToday && !isDone {
                        Circle()
                            .strokeBorder(accentColor.opacity(0.4), lineWidth: 1)
                            .frame(width: size, height: size)
                    }
                }
            }
        }
    }
}

// MARK: — Previews

#Preview("Не выполнена") {
    let habit = Habit(name: "Медитация", colorHex: "2DD4A0", sortOrder: 0)
    return HabitCardView(habit: habit, onToggle: {}, onEdit: {}, onDelete: {}, onShowDetail: {})
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
    return HabitCardView(habit: habit, onToggle: {}, onEdit: {}, onDelete: {}, onShowDetail: {})
        .padding()
        .background(Color.bgPrimary)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
