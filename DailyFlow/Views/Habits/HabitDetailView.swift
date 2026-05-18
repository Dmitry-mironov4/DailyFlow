import SwiftData
import SwiftUI

struct HabitDetailView: View {
    let habit: Habit

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var isDoneToday: Bool {
        HabitService.isDone(habit, on: today)
    }

    private var currentStreak: Int {
        HabitService.streak(for: habit, relativeTo: today).value
    }

    private var recordStreak: Int {
        maxStreak(for: habit)
    }

    private var accentColor: Color { Color(hex: habit.colorHex) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                streakCard
                heatmapSection
                toggleButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.bgPrimary)
        .presentationDetents([.medium, .large])
    }

    // MARK: — Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(accentColor)
                .frame(width: 18, height: 18)
            Text(habit.name)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.textGhost)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: — Streak card

    private var streakCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ТЕКУЩИЙ").dfCaption()
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(currentStreak > 0 ? accentColor : Color.textGhost)
                    Text("\(currentStreak) дней подряд")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(currentStreak > 0 ? accentColor : Color.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("РЕКОРД").dfCaption()
                Text("\(recordStreak) дней")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentAmber)
            }
        }
        .dfCard()
    }

    // MARK: — Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("16 НЕДЕЛЬ").dfCaption()
            HabitHeatmapView(habit: habit, today: today)
                .dfCard()
        }
    }

    // MARK: — Toggle button

    private var toggleButton: some View {
        Button {
            Haptics.tap(.medium)
            HabitService.toggleToday(habit, in: ctx)
        } label: {
            Text(isDoneToday ? "Снять отметку" : "Отметить выполненной")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isDoneToday ? Color.textSecondary : Color.bgPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isDoneToday
                        ? Color.bgCard
                        : accentColor,
                    in: .rect(cornerRadius: 12)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: — Record streak computation

    private func maxStreak(for habit: Habit) -> Int {
        let cal = Calendar.current
        let sortedDates = habit.logs
            .map { cal.startOfDay(for: $0.date) }
            .sorted()
        guard !sortedDates.isEmpty else { return 0 }

        var maxRun = 1
        var currentRun = 1
        for i in 1 ..< sortedDates.count {
            let prev = sortedDates[i - 1]
            let curr = sortedDates[i]
            if let diff = cal.dateComponents([.day], from: prev, to: curr).day, diff == 1 {
                currentRun += 1
                maxRun = max(maxRun, currentRun)
            } else {
                currentRun = 1
            }
        }
        return maxRun
    }
}

#Preview {
    let container = ModelContainer.preview(.longStreak)
    return Text("Preview")
        .sheet(isPresented: .constant(true)) {
            if let habit = try? container.mainContext.fetch(FetchDescriptor<Habit>()).first {
                HabitDetailView(habit: habit)
                    .modelContainer(container)
                    .preferredColorScheme(.dark)
            }
        }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
