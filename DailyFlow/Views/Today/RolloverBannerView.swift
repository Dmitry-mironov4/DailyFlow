import SwiftUI

struct RolloverBannerView: View {
    let count: Int
    let onMove: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("Незавершённых: \(count)")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)

            Spacer()

            Button {
                Haptics.tap(.light)
                onMove()
            } label: {
                Text("Перенести")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentWhite)
            }
            .buttonStyle(.plain)

            Text(" · ")
                .font(.system(size: 13))
                .foregroundStyle(Color.separator)

            Button {
                Haptics.tap(.medium)
                onDiscard()
            } label: {
                Text("Удалить")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentDestructive)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgElevated, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.separator, lineWidth: 1)
        )
    }
}

#Preview {
    RolloverBannerView(count: 3, onMove: {}, onDiscard: {})
        .padding(.horizontal, 16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
