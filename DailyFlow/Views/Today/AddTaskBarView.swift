import SwiftUI

struct AddTaskBarView: View {
    @Binding var text: String
    let onSubmit: (String) -> Void
    @FocusState private var focused: Bool

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
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if focused {
                Rectangle()
                    .fill(Color.accentTeal)
                    .frame(height: 1)
            }
        }
        .contentShape(.rect)
        .onTapGesture { focused = true }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Haptics.tap(.light)
        onSubmit(trimmed)
        text = ""
    }
}

#Preview {
    @Previewable @State var text = ""
    AddTaskBarView(text: $text, onSubmit: { _ in })
        .padding(.horizontal, 16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
