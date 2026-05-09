import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dateAnchor = Calendar.current.startOfDay(for: .now)

    var body: some View {
        InsightsContentView(today: dateAnchor)
            .id(dateAnchor)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                let now = Calendar.current.startOfDay(for: .now)
                if now != dateAnchor { dateAnchor = now }
            }
    }
}

#Preview {
    InsightsView()
        .modelContainer(.preview(.fullWeek))
        .preferredColorScheme(.dark)
}
