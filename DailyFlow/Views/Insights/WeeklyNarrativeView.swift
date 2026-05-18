import SwiftUI

struct WeeklyNarrativeView: View {
    let tasksRate: Double?
    let habitsRate: Double?
    let moodRate: Double?
    let topStreak: Int

    private var text: String {
        if tasksRate == nil, habitsRate == nil, moodRate == nil {
            return "Начни пользоваться приложением — и здесь появятся инсайты 📊"
        }
        let hr = habitsRate ?? 0
        let tr = tasksRate ?? 0
        if hr > 0.8, tr > 0.7 { return "Огонь 🔥 — продуктивная неделя по всем фронтам" }
        if hr > 0.8 { return "Сильная неделя — \(Int(hr * 100))% привычек выполнено 💪" }
        if hr < 0.3, habitsRate != nil { return "Неделя была непростой, но ты продолжаешь 🌱" }
        if topStreak >= 7 { return "Стрик \(topStreak) дней 🔥 — так держать" }
        return "Продолжаешь строить привычки — \(topStreak > 0 ? "\(topStreak) дней подряд" : "начни сегодня")"
    }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dfCard()
            .padding(.horizontal, 16)
    }
}

#Preview {
    VStack(spacing: 12) {
        WeeklyNarrativeView(tasksRate: nil, habitsRate: nil, moodRate: nil, topStreak: 0)
        WeeklyNarrativeView(tasksRate: 0.75, habitsRate: 0.85, moodRate: 0.7, topStreak: 5)
        WeeklyNarrativeView(tasksRate: 0.4, habitsRate: 0.2, moodRate: 0.5, topStreak: 2)
        WeeklyNarrativeView(tasksRate: 0.9, habitsRate: 0.5, moodRate: 0.6, topStreak: 10)
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
