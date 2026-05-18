import SwiftUI

struct StreakRowView: View {
    let habit: Habit
    let value: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(value)")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.textGhost)
                .monospacedDigit()
                .frame(width: 28, alignment: .trailing)
            Text(habit.name)
                .dfBody()
            Spacer()
            Text("\(value) дн.")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(height: 36)
    }
}

#Preview {
    let habit = Habit(name: "Утренняя пробежка", colorHex: "808080", sortOrder: 0)
    return VStack(spacing: 12) {
        StreakRowView(habit: habit, value: 12, isActive: true)
        StreakRowView(habit: habit, value: 7, isActive: false)
    }
    .dfCard()
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
