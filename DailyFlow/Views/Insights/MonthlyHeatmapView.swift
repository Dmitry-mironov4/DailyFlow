import SwiftData
import SwiftUI

struct MonthlyHeatmapView: View {
    let today: Date

    @Environment(\.modelContext) private var ctx

    // 5 недель = 35 дней. Сетка: столбцы = недели, строки = дни Пн..Вс
    private var grid: [[Date]] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: today)
        // Находим понедельник 5 недель назад
        let raw = cal.date(byAdding: .day, value: -34, to: todayStart)!
        let weekday = cal.component(.weekday, from: raw) // 1=Вс, 2=Пн...
        let offset = weekday == 1 ? -6 : -(weekday - 2)
        let start = cal.date(byAdding: .day, value: offset, to: raw)!

        var result: [[Date]] = []
        var cursor = start
        for _ in 0 ..< 5 {
            var col: [Date] = []
            for _ in 0 ..< 7 {
                col.append(cal.startOfDay(for: cursor))
                cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
            }
            result.append(col)
        }
        return result
    }

    private let dayLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Подписи дней
            VStack(alignment: .leading, spacing: 4) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textGhost)
                        .frame(width: 18, height: 14)
                }
            }

            // Сетка
            HStack(alignment: .top, spacing: 4) {
                ForEach(0 ..< grid.count, id: \.self) { col in
                    VStack(spacing: 4) {
                        ForEach(0 ..< 7, id: \.self) { row in
                            cell(for: grid[col][row])
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for date: Date) -> some View {
        let todayStart = Calendar.current.startOfDay(for: today)
        let isFuture = date > todayStart
        let isToday = Calendar.current.isDateInToday(date)
        let activity = isFuture ? 0 : activityCount(for: date)

        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isFuture ? Color.clear : cellColor(activity: activity))
                .frame(width: 14, height: 14)
            if isToday {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.accentTeal, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
            }
        }
    }

    private func cellColor(activity: Int) -> Color {
        switch activity {
        case 0: return Color.bgPixelInactive
        case 1: return Color.accentTeal.opacity(0.25)
        case 2, 3: return Color.accentTeal.opacity(0.55)
        default: return Color.accentTeal
        }
    }

    private func activityCount(for date: Date) -> Int {
        var count = 0
        let taskPred = #Predicate<DailyTask> { $0.date == date && $0.isCompleted == true }
        if let tasks = try? ctx.fetch(FetchDescriptor<DailyTask>(predicate: taskPred)),
           !tasks.isEmpty { count += 1 }
        let logPred = #Predicate<HabitLog> { $0.date == date }
        if let logs = try? ctx.fetch(FetchDescriptor<HabitLog>(predicate: logPred)) {
            count += logs.count
        }
        let entryPred = #Predicate<JournalEntry> { $0.date == date }
        if let entries = try? ctx.fetch(FetchDescriptor<JournalEntry>(predicate: entryPred)),
           !entries.isEmpty { count += 1 }
        return count
    }
}

#Preview {
    MonthlyHeatmapView(today: .now)
        .dfCard()
        .padding()
        .background(Color.bgPrimary)
        .modelContainer(.preview(.fullWeek))
        .preferredColorScheme(.dark)
}
