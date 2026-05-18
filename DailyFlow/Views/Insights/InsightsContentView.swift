import SwiftData
import SwiftUI

struct InsightsContentView: View {
    let today: Date

    @Environment(\.modelContext) private var ctx
    @Query private var allTasks: [DailyTask]
    @Query private var allHabits: [Habit]
    @Query private var allEntries: [JournalEntry]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Инсайты")
                    .dfTitle()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                WeeklyNarrativeView(
                    tasksRate: tasksRate,
                    habitsRate: habitsRate,
                    moodRate: moodRate,
                    topStreak: topStreaks.first?.value ?? 0
                )

                metricsRow
                streaksSection
                moodSection
                heatmapSection
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }

    // MARK: — Reactivity bridge

    private var dataChangeToken: Int {
        allTasks.count &+ allHabits.count &+ allEntries.count
    }

    // MARK: — Метрики

    private var tasksRate: Double? {
        _ = dataChangeToken
        return InsightsService.tasksRate(today: today, in: ctx)
    }

    private var habitsRate: Double? {
        _ = dataChangeToken
        return InsightsService.habitsRate(today: today, in: ctx)
    }

    private var moodRate: Double? {
        _ = dataChangeToken
        return InsightsService.moodRate(today: today, in: ctx)
    }

    private var previousTasksRate: Double? {
        _ = dataChangeToken
        return InsightsService.previousTasksRate(today: today, in: ctx)
    }

    private var previousHabitsRate: Double? {
        _ = dataChangeToken
        return InsightsService.previousHabitsRate(today: today, in: ctx)
    }

    private var previousMoodRate: Double? {
        _ = dataChangeToken
        return InsightsService.previousMoodRate(today: today, in: ctx)
    }

    private var topStreaks: [StreakItem] {
        _ = dataChangeToken
        return InsightsService.topStreaks(limit: 3, today: today, in: ctx)
    }

    private var moodSeries: [MoodPoint] {
        _ = dataChangeToken
        return InsightsService.moodSeries(today: today, in: ctx)
    }

    // MARK: — Секции

    private var metricsRow: some View {
        HStack(spacing: 12) {
            MetricCardView(kind: .tasks, rate: tasksRate, previousRate: previousTasksRate)
            MetricCardView(kind: .habits, rate: habitsRate, previousRate: previousHabitsRate)
            MetricCardView(kind: .mood, rate: moodRate, previousRate: previousMoodRate)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var streaksSection: some View {
        let streaks = topStreaks
        if !streaks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("ЛУЧШИЕ СТРИКИ").dfCaption()
                    .padding(.horizontal, 16)
                VStack(spacing: 12) {
                    ForEach(streaks) { item in
                        StreakRowView(habit: item.habit, value: item.value, isActive: item.isActive)
                    }
                }
                .dfCard()
                .padding(.horizontal, 16)
            }
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("НАСТРОЕНИЕ — ПОСЛЕДНИЕ 7 ДНЕЙ").dfCaption()
                .padding(.horizontal, 16)
            MoodChartView(series: moodSeries, today: today)
                .dfCard()
                .padding(.horizontal, 16)
        }
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("АКТИВНОСТЬ — 5 НЕДЕЛЬ").dfCaption()
                .padding(.horizontal, 16)
            MonthlyHeatmapView(today: today)
                .dfCard()
                .padding(.horizontal, 16)
        }
    }
}

#Preview("Empty") {
    InsightsContentView(today: Calendar.current.startOfDay(for: .now))
        .modelContainer(.preview(.empty))
        .preferredColorScheme(.dark)
}

#Preview("Full week") {
    InsightsContentView(today: Calendar.current.startOfDay(for: .now))
        .modelContainer(.preview(.fullWeek))
        .preferredColorScheme(.dark)
}
