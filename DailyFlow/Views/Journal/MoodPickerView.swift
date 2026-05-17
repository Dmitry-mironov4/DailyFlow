import SwiftUI

struct MoodPickerView: View {
    let selectedScore: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1 ... 5, id: \.self) { score in
                MoodTile(score: score, isSelected: score == selectedScore)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(score) }
            }
        }
        .frame(height: 72)
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
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? moodColor.opacity(0.15) : Color.bgCard)
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isSelected ? moodColor.opacity(0.55) : Color.clear,
                    lineWidth: 1.5
                )
            Text(emoji)
                .font(.system(size: isSelected ? 30 : 26))
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .frame(maxWidth: .infinity)
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
