import SwiftUI

enum MetricKind {
    case tasks
    case habits
    case mood

    var caption: String {
        switch self {
        case .tasks: "ЗАДАЧИ"
        case .habits: "ПРИВЫЧКИ"
        case .mood: "НАСТРОЕНИЕ"
        }
    }

    var label: String {
        switch self {
        case .tasks: "закрыто за 7 дн."
        case .habits: "в среднем за день"
        case .mood: "в среднем за 7 дн."
        }
    }
}

struct MetricCardView: View {
    let kind: MetricKind
    let rate: Double?
    var previousRate: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind.caption).dfCaption()

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formattedValue)
                    .dfStat()
                    .foregroundStyle(rate == nil ? Color.textGhost : Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let trend = trendText {
                    Text(trend)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }

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
        return "\(Int((rate * 100).rounded()))%"
    }

    private var trendText: String? {
        guard let current = rate, let prev = previousRate else { return nil }
        let diff = current - prev
        if diff > 0.04 { return "↑ +\(Int((diff * 100).rounded()))%" }
        if diff < -0.04 { return "↓ \(Int((diff * 100).rounded()))%" }
        return "→"
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.bgElevated)
                Rectangle()
                    .fill(Color.accentWhite)
                    .frame(width: max(0, geo.size.width * (rate ?? 0)))
            }
        }
        .frame(height: 3)
        .clipShape(.rect(cornerRadius: 1.5))
    }
}

#Preview {
    HStack(spacing: 12) {
        MetricCardView(kind: .tasks, rate: 0.75, previousRate: 0.60)
        MetricCardView(kind: .habits, rate: 0.62, previousRate: 0.70)
        MetricCardView(kind: .mood, rate: 0.84, previousRate: 0.83)
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
