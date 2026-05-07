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
                    .foregroundStyle(Color.accentTeal)
            }
            .buttonStyle(.plain)

            Text(" · ")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)

            Button {
                Haptics.tap(.medium)
                onDiscard()
            } label: {
                Text("Очистить")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .dfCard()
    }
}

#Preview {
    RolloverBannerView(count: 3, onMove: {}, onDiscard: {})
        .padding(.horizontal, 16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
