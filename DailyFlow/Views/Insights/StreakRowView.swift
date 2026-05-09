import SwiftUI

struct StreakRowView: View {
    let habit: Habit
    let value: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: habit.colorHex))
                .frame(width: 8, height: 8)
            Text(habit.name).dfBody()
            Spacer()
            Text("\(value)")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? Color(hex: habit.colorHex) : Color.textGhost)
        }
        .frame(height: 36)
    }
}

#Preview {
    let habit = Habit(name: "Утренняя пробежка", colorHex: "2DD4A0", sortOrder: 0)
    return VStack(spacing: 12) {
        StreakRowView(habit: habit, value: 12, isActive: true)
        StreakRowView(habit: habit, value: 7, isActive: false)
    }
    .dfCard()
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
