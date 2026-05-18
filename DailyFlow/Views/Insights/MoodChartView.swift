import Charts
import SwiftUI

struct MoodChartView: View {
    let series: [MoodPoint]
    let today: Date

    private var pointsWithData: [MoodPoint] {
        series.filter { $0.score != nil }
    }

    var body: some View {
        if pointsWithData.count < 2 {
            Text("Записывай настроение каждый день")
                .dfLabel()
                .frame(height: 120)
                .frame(maxWidth: .infinity)
        } else {
            Chart {
                ForEach(series) { point in
                    RuleMark(x: .value("День", point.date, unit: .day))
                        .foregroundStyle(.clear)
                        .lineStyle(StrokeStyle(lineWidth: 0))
                }
                ForEach(pointsWithData) { point in
                    let score = Double(point.score!)
                    BarMark(
                        x: .value("День", point.date, unit: .day),
                        y: .value("Настроение", score)
                    )
                    .foregroundStyle(
                        Color.accentWhite.opacity(score / 5.0 * 0.6 + 0.4)
                    )
                    .cornerRadius(3)
                }
            }
            .chartYScale(domain: 0 ... 5)
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
}

#Preview("Full week") {
    let today = Calendar.current.startOfDay(for: .now)
    let series: [MoodPoint] = (0 ..< 7).map { i in
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
    let series: [MoodPoint] = (0 ..< 7).map { i in
        let day = Calendar.current.date(byAdding: .day, value: i - 6, to: today)!
        return MoodPoint(date: day, score: scores[i])
    }
    return MoodChartView(series: series, today: today)
        .dfCard()
        .padding()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
