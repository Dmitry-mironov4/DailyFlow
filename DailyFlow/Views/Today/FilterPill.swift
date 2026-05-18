import SwiftUI

struct FilterPill: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.bgElevated : Color.bgCard,
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.accentWhite.opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    HStack(spacing: 8) {
        FilterPill(label: "Все", isSelected: true) {}
        FilterPill(label: "📥 Входящие", isSelected: false) {}
        FilterPill(label: "💼 Работа", isSelected: false) {}
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
