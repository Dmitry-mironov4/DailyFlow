import SwiftData
import SwiftUI

struct JournalView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    @Query private var entries: [JournalEntry]

    init() {
        let today = Calendar.current.startOfDay(for: .now)
        _entries = Query(filter: #Predicate<JournalEntry> { $0.date == today })
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            MoodPickerView(selectedScore: entries.first?.moodScore) { score in
                Haptics.tap(.light)
                JournalService.setMood(score, in: ctx)
            }

            if entries.first?.moodScore != nil {
                ActivityPickerView(selected: activitiesBinding)
                    .padding(.top, 4)
                    .padding(.horizontal, -16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            JournalEditorView(entry: entries.first) { newText in
                JournalService.setText(newText, in: ctx)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.25), value: entries.first?.moodScore)
        .background(Color.bgPrimary)
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
    }

    private var activitiesBinding: Binding<[String]> {
        Binding(
            get: { entries.first?.activities ?? [] },
            set: { JournalService.setActivities($0, in: ctx) }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateCaption)
                .dfCaption()
            if let entry = entries.first {
                Text(timeCaption(for: entry.createdAt))
                    .dfLabel()
                    .foregroundStyle(Color.textGhost)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let dayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "EEEE, d MMMM"
        return fmt
    }()

    private static let timeFormatterToday: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "'Сегодня, 'HH:mm"
        return fmt
    }()

    private static let timeFormatterOther: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "d MMM, HH:mm"
        return fmt
    }()

    private var dateCaption: String {
        Self.dayFormatter.string(from: .now).uppercased()
    }

    private func timeCaption(for date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? Self.timeFormatterToday.string(from: date)
            : Self.timeFormatterOther.string(from: date)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

#Preview("Empty") {
    JournalView()
        .modelContainer(ModelContainer.preview(.emptyJournal))
        .preferredColorScheme(.dark)
}

#Preview("Mood only") {
    JournalView()
        .modelContainer(ModelContainer.preview(.moodOnly))
        .preferredColorScheme(.dark)
}

#Preview("Full entry") {
    JournalView()
        .modelContainer(ModelContainer.preview(.fullJournal))
        .preferredColorScheme(.dark)
}

#Preview("Long text") {
    JournalView()
        .modelContainer(ModelContainer.preview(.longJournal))
        .preferredColorScheme(.dark)
}
