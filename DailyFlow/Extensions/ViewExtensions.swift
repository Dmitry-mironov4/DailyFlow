import SwiftUI

extension View {
    func dfTitle() -> some View {
        font(.system(size: 21, weight: .medium))
            .foregroundStyle(Color.textPrimary)
    }

    func dfBody() -> some View {
        font(.system(size: 13, weight: .regular))
            .foregroundStyle(Color.textPrimary)
    }

    func dfCaption() -> some View {
        font(.system(size: 10, weight: .regular))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.textGhost)
    }

    func dfCard() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.bgCard, in: .rect(cornerRadius: 12))
    }

    func dfLabel() -> some View {
        font(.system(size: 11, weight: .regular))
            .foregroundStyle(Color.textSecondary)
    }

    func dfAccentCard(color: Color) -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(color.opacity(0.08), in: .rect(cornerRadius: 12))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(color)
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }
    }

    func dfStat() -> some View {
        font(.system(size: 28, weight: .semibold))
    }
}
