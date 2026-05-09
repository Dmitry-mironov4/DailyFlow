import SwiftUI
import Charts

struct MoodChartView: View {
    /// Ровно 7 элементов от today−6 до today.
    let series: [MoodPoint]
    let today: Date

    var body: some View {
        Chart {
            // Невидимая референс-точка для каждого дня:
            // гарантирует, что ось X не схлопнется при отсутствии BarMark.
            ForEach(series) { point in
                RuleMark(x: .value("День", point.date, unit: .day))
                    .foregroundStyle(.clear)
                    .lineStyle(StrokeStyle(lineWidth: 0))
            }
            // Реальные бары — только для дней с данными.
            ForEach(series) { point in
                if let score = point.score {
                    BarMark(
                        x: .value("День", point.date, unit: .day),
                        y: .value("Настроение", score)
                    )
                    .foregroundStyle(Color.accentPurple)
                    .cornerRadius(2)
                }
            }
        }
        .chartYScale(domain: 0...5)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: series.map(\.date)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 10))
                            .foregroundStyle(
                                Calendar.current.isDate(date, inSameDayAs: today)
                                    ? Color.textPrimary : Color.textGhost
                            )
                    }
                }
            }
        }
        .frame(height: 120)
    }
}

#Preview("Full week") {
    let today = Calendar.current.startOfDay(for: .now)
    let series: [MoodPoint] = (0..<7).map { i in
        let day = Calendar.current.date(byAdding: .day, value: i - 6, to: today)!
        return MoodPoint(date: day, score: [3, 4, 2, 5, 4, 3, 5][i])
    }
    return MoodChartView(series: series, today: today)
        .dfCard()
        .padding()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}

#Preview("With gaps") {
    let today = Calendar.current.startOfDay(for: .now)
    let scores: [Int?] = [3, nil, nil, 4, 5, nil, 4]
    let series: [MoodPoint] = (0..<7).map { i in
        let day = Calendar.current.date(byAdding: .day, value: i - 6, to: today)!
        return MoodPoint(date: day, score: scores[i])
    }
    return MoodChartView(series: series, today: today)
        .dfCard()
        .padding()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
