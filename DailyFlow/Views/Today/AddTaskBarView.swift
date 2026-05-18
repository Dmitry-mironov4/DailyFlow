import SwiftUI

struct AddTaskBarView: View {
    @Binding var text: String
    let onSubmit: (String, Int) -> Void
    @FocusState private var focused: Bool
    @State private var priority: Int = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: focused ? "circle.fill" : "plus")
                .foregroundStyle(Color.accentTeal)
                .frame(width: 16, height: 16)
                .animation(.easeInOut(duration: 0.2), value: focused)

            TextField(focused ? "Новая задача…" : "Добавить задачу", text: $text)
                .focused($focused)
                .submitLabel(.return)
                .onSubmit(submit)
                .foregroundStyle(focused ? Color.textPrimary : Color.textGhost)
                .font(.system(size: 13))

            if focused {
                Button {
                    priority = (priority + 1) % 3
                    Haptics.tap(.light)
                } label: {
                    Image(systemName: priority > 0 ? "circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(priorityColor)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if focused {
                Rectangle()
                    .fill(Color.accentTeal)
                    .frame(height: 1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: focused)
        .contentShape(.rect)
        .onTapGesture { focused = true }
    }

    private var priorityColor: Color {
        switch priority {
        case 1: return Color.accentAmber
        case 2: return Color(hex: 0xFF6B6B)
        default: return Color.textGhost
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Haptics.tap(.light)
        onSubmit(trimmed, priority)
        text = ""
        priority = 0
    }
}

#Preview {
    @Previewable @State var text = ""
    AddTaskBarView(text: $text, onSubmit: { _, _ in })
        .padding(.horizontal, 16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
