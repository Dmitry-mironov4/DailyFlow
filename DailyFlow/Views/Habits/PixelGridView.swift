import SwiftUI
import SwiftData

struct PixelGridView: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 4) {
            ForEach(lastSevenDays, id: \.self) { date in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        HabitService.isDone(habit, on: date)
                            ? Color(hex: habit.colorHex)
                            : Color.bgPixelInactive
                    )
                    .frame(width: 28, height: 28)
                    .animation(.easeInOut(duration: 0.15), value: HabitService.isDone(habit, on: date))
            }
        }
    }

    private var lastSevenDays: [Date] {
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<7).reversed().map {
            Calendar.current.date(byAdding: .day, value: -$0, to: today)!
        }
    }
}

#Preview("Без выполнений") {
    let habit = Habit(name: "Медитация", colorHex: "2DD4A0", sortOrder: 0)
    return PixelGridView(habit: habit)
        .padding()
        .background(Color.bgCard)
        .preferredColorScheme(.dark)
}

#Preview("С выполнениями") {
    let container = ModelContainer.preview(.empty)
    let habit = Habit(name: "Спорт", colorHex: "F0A23B", sortOrder: 0)
    container.mainContext.insert(habit)
    let today = Calendar.current.startOfDay(for: .now)
    for i in 0..<5 {
        let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
        container.mainContext.insert(HabitLog(date: date, habit: habit))
    }
    return PixelGridView(habit: habit)
        .padding()
        .background(Color.bgCard)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
