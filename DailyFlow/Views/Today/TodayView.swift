import SwiftUI

struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dateAnchor = Calendar.current.startOfDay(for: .now)

    var body: some View {
        TodayContentView(dateAnchor: dateAnchor)
            .id(dateAnchor)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                let now = Calendar.current.startOfDay(for: .now)
                if now != dateAnchor { dateAnchor = now }
            }
    }
}

#Preview {
    TodayView()
        .preferredColorScheme(.dark)
}
