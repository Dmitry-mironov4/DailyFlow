import SwiftUI

struct MoodPickerView: View {
    let selectedScore: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1 ... 5, id: \.self) { score in
                MoodTile(score: score, isSelected: score == selectedScore)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(score) }
            }
        }
        .frame(height: 56)
    }
}

private struct MoodTile: View {
    let score: Int
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentTeal : Color.bgCard)
            Text("\(score)")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
