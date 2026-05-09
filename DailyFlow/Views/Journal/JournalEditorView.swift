import SwiftData
import SwiftUI

struct JournalEditorView: View {
    let entry: JournalEntry?
    let onTextChange: (String) -> Void

    @State private var text: String = ""
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Что сегодня было?")
                    .dfBody()
                    .foregroundStyle(Color.textGhost)
                    .padding(.top, 12)
                    .padding(.leading, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .focused($focused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(Color.bgCard)
                .dfBody()
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { text = entry?.text ?? "" }
        .onChange(of: entry?.text ?? "") { _, new in
            if new != text { text = new }
        }
        .onChange(of: text) { _, new in
            saveTask?.cancel()
            saveTask = Task { [new] in
                try? await Task.sleep(for: .milliseconds(1500))
                if Task.isCancelled { return }
                await MainActor.run { onTextChange(new) }
            }
        }
        .onDisappear {
            saveTask?.cancel()
            onTextChange(text)
        }
    }
}

#Preview("Empty") {
    JournalEditorView(entry: nil) { _ in }
        .padding(16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}

#Preview("With text") {
    let container = ModelContainer.preview(.fullJournal)
    let entry = (try? container.mainContext.fetch(FetchDescriptor<JournalEntry>()))?.first
    return JournalEditorView(entry: entry) { _ in }
        .padding(16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
        .modelContainer(container)
}
