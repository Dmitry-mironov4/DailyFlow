import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Сегодня", systemImage: "calendar") }
            HabitsView()
                .tabItem { Label("Привычки", systemImage: "square.grid.2x2") }
            JournalView()
                .tabItem { Label("Дневник", systemImage: "note.text") }
            placeholder
                .tabItem { Label("Инсайты", systemImage: "chart.bar") }
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .onAppear(perform: configureTabBar)
    }

    private var placeholder: some View {
        Text("Скоро")
            .foregroundStyle(Color.textGhost)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgPrimary)
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
