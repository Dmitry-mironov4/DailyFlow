import SwiftUI

struct ActivityPickerView: View {
    @Binding var selected: [String]

    private let options = [
        "😴 Устал", "🏃 Спорт", "👥 С людьми",
        "🏠 Дома", "💼 Работа", "📚 Учёба", "🎮 Отдых", "🍕 Еда",
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isOn = selected.contains(option)
                    Text(option)
                        .font(.system(size: 13))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(
                            isOn ? Color.bgElevated : Color.bgCard,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                isOn ? Color.accentWhite : Color.clear,
                                lineWidth: 1
                            )
                        )
                        .foregroundStyle(isOn ? Color.textPrimary : Color.textSecondary)
                        .onTapGesture {
                            if isOn { selected.removeAll { $0 == option } } else { selected.append(option) }
                            Haptics.tap(.light)
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    @Previewable @State var selected = ["🏃 Спорт"]
    ActivityPickerView(selected: $selected)
        .padding(.vertical, 8)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
