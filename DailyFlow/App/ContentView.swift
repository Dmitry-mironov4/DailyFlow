import SwiftUI

struct ContentView: View {
    // Явный selection + .tag() обязателен: без него SwiftUI на iOS 26
    // идентифицирует tab-children по структурной идентичности. TodayView
    // и InsightsView имеют идентичные signatures (`@State Date dateAnchor`
    // + `body` с `.id(dateAnchor)` и одинаковым значением), поэтому первый
    // тап на «Инсайты» после старта приложения проглатывался.
    @State private var selection: Int = 0

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tabItem { Label("Сегодня", systemImage: "calendar") }
                .tag(0)
            HabitsView()
                .tabItem { Label("Привычки", systemImage: "square.grid.2x2") }
                .tag(1)
            JournalView()
                .tabItem { Label("Дневник", systemImage: "note.text") }
                .tag(2)
            InsightsView()
                .tabItem { Label("Инсайты", systemImage: "chart.bar") }
                .tag(3)
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .onAppear(perform: configureTabBar)
    }

    @MainActor
    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.bgPrimary)
        let ghost = UIColor(Color.textGhost)
        let primary = UIColor(Color.textPrimary)
        appearance.stackedLayoutAppearance.normal.iconColor = ghost
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: ghost]
        appearance.stackedLayoutAppearance.selected.iconColor = primary
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: primary]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
