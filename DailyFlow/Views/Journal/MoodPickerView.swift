import SwiftUI

struct MoodPickerView: View {
    let selectedScore: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1 ... 5, id: \.self) { score in
                MoodTile(score: score, isSelected: score == selectedScore)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(score) }
            }
        }
        .frame(height: 80)
    }
}

private struct MoodTile: View {
    let score: Int
    let isSelected: Bool

    private var label: String {
        switch score {
        case 1: "Плохо"
        case 2: "Так себе"
        case 3: "Норм"
        case 4: "Хорошо"
        default: "Отлично"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.bgElevated : Color.bgCard)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.accentWhite : Color.separator,
                        lineWidth: isSelected ? 1.5 : 1
                    )
                Text("\(score)")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textGhost)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textGhost)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview("None selected") {
    MoodPickerView(selectedScore: nil) { _ in }
        .padding(16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}

#Preview("Score 3 selected") {
    MoodPickerView(selectedScore: 3) { _ in }
        .padding(16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}

#Preview("Score 5 selected") {
    MoodPickerView(selectedScore: 5) { _ in }
        .padding(16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
