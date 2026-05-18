import SwiftData
import SwiftUI

struct HabitHeatmapView: View {
    let habit: Habit
    let today: Date

    /// 16 недель = 112 дней. Столбцы = недели (0..15), строки = дни (0=Пн..6=Вс)
    private var grid: [[Date?]] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: today)
        // Находим ближайший следующий воскресенья (конец сетки)
        // Строим 112 дней назад от todayStart
        let startDay = cal.date(byAdding: .day, value: -111, to: todayStart)!

        // Выравниваем startDay на понедельник
        let weekday = cal.component(.weekday, from: startDay) // 1=Вс, 2=Пн...7=Сб
        let mondayOffset = weekday == 1 ? -6 : -(weekday - 2)
        let alignedStart = cal.date(byAdding: .day, value: mondayOffset, to: startDay)!

        // Генерируем 16 столбцов × 7 строк
        var columns: [[Date?]] = []
        var cursor = alignedStart
        for _ in 0 ..< 16 {
            var col: [Date?] = []
            for _ in 0 ..< 7 {
                let day = cal.startOfDay(for: cursor)
                col.append(day > todayStart ? nil : day)
                cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
            }
            columns.append(col)
        }
        return columns
    }

    private var accentColor: Color {
        Color.accentWhite
    }

    var body: some View {
        HStack(alignment: .top, spacing: 3) {
            ForEach(0 ..< grid.count, id: \.self) { col in
                VStack(spacing: 3) {
                    ForEach(0 ..< 7, id: \.self) { row in
                        cell(for: grid[col][row])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for date: Date?) -> some View {
        let size: CGFloat = 11
        if let date {
            let isDone = HabitService.isDone(habit, on: date)
            let isToday = Calendar.current.isDateInToday(date)
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isDone ? accentColor : Color.bgElevated)
                    .frame(width: size, height: size)
                if isToday {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(accentColor, lineWidth: 1.5)
                        .frame(width: size, height: size)
                }
            }
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }
}

#Preview {
    let habit = Habit(name: "Медитация", colorHex: "2DD4A0", sortOrder: 0)
    HabitHeatmapView(habit: habit, today: .now)
        .padding()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
