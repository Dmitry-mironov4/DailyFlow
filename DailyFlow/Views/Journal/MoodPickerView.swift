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
        .frame(height: 96)
    }
}

private struct MoodTile: View {
    let score: Int
    let isSelected: Bool

    private var emoji: String {
        switch score {
        case 1: return "😔"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "😄"
        }
    }

    private var label: String {
        switch score {
        case 1: return "Тяжело"
        case 2: return "Грустно"
        case 3: return "Нейтрально"
        case 4: return "Хорошо"
        default: return "Отлично"
        }
    }

    private var moodColor: Color {
        switch score {
        case 1: return Color(hex: 0xFF6B6B)
        case 2: return Color(hex: 0xF0A23B)
        case 3: return Color(hex: 0xF5C842)
        case 4: return Color(hex: 0x7ED3A0)
        default: return Color.accentTeal
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isSelected ? moodColor.opacity(0.2) : Color.bgCard)
                Circle()
                    .strokeBorder(
                        isSelected ? moodColor : Color.clear,
                        lineWidth: 2
                    )
                Text(emoji)
                    .font(.system(size: isSelected ? 30 : 24))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isSelected ? 1.12 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? moodColor : Color.textGhost)
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
