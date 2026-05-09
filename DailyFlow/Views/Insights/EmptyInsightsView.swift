import SwiftUI

struct EmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Нужно ещё немного данных")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color.textGhost)
            Text("Пользуйся приложением 3 дня,\nчтобы увидеть статистику")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

#Preview {
    EmptyInsightsView()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
