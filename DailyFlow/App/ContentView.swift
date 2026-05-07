import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Сегодня", systemImage: "checkmark.circle")
                }
            Text("Скоро")
                .tabItem {
                    Label("Привычки", systemImage: "flame")
                }
            Text("Скоро")
                .tabItem {
                    Label("Дневник", systemImage: "book.closed")
                }
            Text("Скоро")
                .tabItem {
                    Label("Инсайты", systemImage: "chart.bar")
                }
        }
        .tint(Color.textPrimary)
        .background(Color.bgPrimary)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
