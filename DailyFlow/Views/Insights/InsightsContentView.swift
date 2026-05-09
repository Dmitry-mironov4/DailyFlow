import SwiftUI
import SwiftData

struct InsightsContentView: View {
    let today: Date

    @Environment(\.modelContext) private var ctx
    // @Query без предикатов — только для реактивного триггера перерендера.
    // Фильтрация и расчёты — в InsightsService через ctx.fetch.
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

                if uniqueDataDays < 3 {
                    EmptyInsightsView()
                        .frame(minHeight: 400)
                } else {
                    metricsRow
                    streaksSection
                    moodSection
                }
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }

    // MARK: — Reactivity bridge

    /// Ссылка на массивы @Query внутри computed-properties — чтобы SwiftUI
    /// перерисовал View при изменении данных. Сами массивы не используются.
    private var dataChangeToken: Int {
        allTasks.count &+ allHabits.count &+ allEntries.count
    }

    // MARK: — Метрики

    private var uniqueDataDays: Int {
        _ = dataChangeToken
        return InsightsService.uniqueDataDays(today: today, in: ctx)
    }

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
            MetricCardView(kind: .tasks, rate: tasksRate)
            MetricCardView(kind: .habits, rate: habitsRate)
            MetricCardView(kind: .mood, rate: moodRate)
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
