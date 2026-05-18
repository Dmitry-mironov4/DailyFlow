import SwiftData
import SwiftUI

struct PixelGridView: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 4) {
            ForEach(lastSevenDays, id: \.self) { date in
                let isDone = HabitService.isDone(habit, on: date)
                RoundedRectangle(cornerRadius: 4)
                    .fill(isDone ? Color.accentWhite.opacity(0.9) : Color.bgElevated)
                    .frame(width: 28, height: 28)
                    .scaleEffect(isDone ? 1.0 : 0.85)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isDone)
            }
        }
    }

    private var lastSevenDays: [Date] {
        let today = Calendar.current.startOfDay(for: .now)
        return (0 ..< 7).reversed().map {
            Calendar.current.date(byAdding: .day, value: -$0, to: today)!
        }
    }
}

#Preview("Без выполнений") {
    let habit = Habit(name: "Медитация", colorHex: "808080", sortOrder: 0)
    return PixelGridView(habit: habit)
        .padding()
        .background(Color.bgCard)
        .preferredColorScheme(.dark)
}

#Preview("С выполнениями") {
    let container = ModelContainer.preview(.empty)
    let habit = Habit(name: "Спорт", colorHex: "808080", sortOrder: 0)
    container.mainContext.insert(habit)
    let today = Calendar.current.startOfDay(for: .now)
    for i in 0 ..< 5 {
        let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
        container.mainContext.insert(HabitLog(date: date, habit: habit))
    }
    return PixelGridView(habit: habit)
        .padding()
        .background(Color.bgCard)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
