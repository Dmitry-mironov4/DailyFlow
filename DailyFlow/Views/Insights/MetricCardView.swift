import SwiftUI

enum MetricKind {
    case tasks
    case habits
    case mood

    var caption: String {
        switch self {
        case .tasks: return "ЗАДАЧИ"
        case .habits: return "ПРИВЫЧКИ"
        case .mood: return "НАСТРОЕНИЕ"
        }
    }

    var label: String {
        switch self {
        case .tasks: return "закрыто за 7 дн."
        case .habits: return "в среднем за день"
        case .mood: return "в среднем за 7 дн."
        }
    }

    var color: Color {
        switch self {
        case .tasks: return .accentTeal
        case .habits: return .accentAmber
        case .mood: return .accentPurple
        }
    }
}

struct MetricCardView: View {
    let kind: MetricKind
    /// rate ∈ [0.0 ... 1.0]; nil → "—"
    let rate: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind.caption).dfCaption()

            Text(formattedValue)
                .dfStat()
                .foregroundStyle(rate == nil ? Color.textGhost : kind.color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            progressBar

            Text(kind.label).dfLabel()
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dfCard()
    }

    private var formattedValue: String {
        guard let rate else { return "—" }
        let percent = Int((rate * 100).rounded())
        return "\(percent)%"
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.bgPixelInactive)
                Rectangle()
                    .fill(kind.color)
                    .frame(width: max(0, geo.size.width * (rate ?? 0)))
            }
        }
        .frame(height: 3)
        .clipShape(.rect(cornerRadius: 1.5))
    }
}

#Preview {
    HStack(spacing: 12) {
        MetricCardView(kind: .tasks, rate: 0.75)
        MetricCardView(kind: .habits, rate: 0.62)
        MetricCardView(kind: .mood, rate: 0.84)
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}

#Preview("Nil values") {
    HStack(spacing: 12) {
        MetricCardView(kind: .tasks, rate: nil)
        MetricCardView(kind: .habits, rate: nil)
        MetricCardView(kind: .mood, rate: nil)
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
