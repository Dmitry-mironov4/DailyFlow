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
                            : Color(hex: "333333")
                    )
                    .frame(width: 28, height: 28)
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
    PixelGridView(habit: Habit(name: "Спорт", colorHex: "F0A23B", sortOrder: 0))
        .padding()
        .background(Color.bgCard)
        .preferredColorScheme(.dark)
}
