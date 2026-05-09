# Journal Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Реализовать экран «Дневник» (третья вкладка TabView) согласно [спеку](../specs/2026-05-09-journal-screen-design.md): хедер с датой, MoodPicker (5 цифровых тайлов), TextEditor с автосохранением (debounce 1.5с) и lazy-созданием `JournalEntry`.

**Architecture:** Pure SwiftUI + `@Query` + `JournalService`-namespace, как у Today/Habits. Без отдельного ViewModel. Lazy-создание записи в `JournalService.setMood/setText`. Cross-midnight не обрабатываем (YAGNI). Нет toast, нет кнопки Obsidian (отложены в спек экспорта).

**Tech Stack:** Swift 6, SwiftUI, SwiftData (`@Model`, `@Query`, `#Predicate`), Swift Testing (`@Test`/`#expect`), Swift Concurrency (`Task.sleep` для debounce). iOS 26+, только тёмная тема.

---

## Контекст для исполнителя

Перед началом ОБЯЗАТЕЛЬНО прочитай:
1. `CLAUDE.md` — общие правила проекта, дизайн-система, структура.
2. `docs/superpowers/specs/2026-05-09-journal-screen-design.md` — спек этой фичи.
3. `DailyFlow/Services/HabitService.swift` — образец сервиса (паттерн `enum`-namespace, `try? ctx.save()`).
4. `DailyFlow/Views/Today/TodayContentView.swift` — образец View с `@Query`, `@Environment(\.modelContext)`, header с датой, `.scrollDismissesKeyboard`.
5. `DailyFlowTests/Services/HabitServiceTests.swift` — образец тестов (Swift Testing, `extension DailyFlowTests`, `@Suite("X", .serialized) @MainActor struct XTests`).
6. `DailyFlow/Extensions/PreviewContainer.swift` — куда добавлять журналские сценарии.

**Инструменты:**
- Линт: `swiftformat --lint .` + `swiftlint`. Должны проходить с 0 issues.
- Билд: `set -o pipefail && xcodebuild -project DailyFlow.xcodeproj -scheme DailyFlow -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build | xcbeautify`
- Тесты: `set -o pipefail && xcodebuild -project DailyFlow.xcodeproj -scheme DailyFlow -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test | xcbeautify`
- Формат: `swiftformat .` (требует подтверждения у пользователя в норме; в плане применяй после согласия).

**Соглашения проекта:**
- Импорты: алфавитный порядок (rule `sorted_imports` отключена, но в коде все файлы отсортированы — следуй конвенции).
- `convenience_type` rule: используй `enum` для namespace, не `struct`.
- `try? ctx.save()` после любой мутации в сервисе.
- Все View-файлы ≤ 150 строк.
- Каждый View: `#Preview` обязателен с `.preferredColorScheme(.dark)` и `.modelContainer(ModelContainer.preview(.scenarioName))`.
- Тесты идут внутри `extension DailyFlowTests { @Suite("Name", .serialized) @MainActor struct NameTests { ... } }`. Корневая `struct DailyFlowTests {}` живёт в `DailyFlowTests/AllTests.swift`.
- `.dfCaption()` модификатор уже даёт `Color.textGhost` (проверено по `ViewExtensions.swift:14-19`). Для хедера даты НЕ переопределяй цвет — используй `.dfCaption()` без `.foregroundStyle()`. Это совпадает с паттерном `TodayContentView.headerView`.

**Frequent commits:** коммитить после каждой Task (обычно после прохождения тестов).

---

## File Structure

**Создать:**
- `DailyFlow/Services/JournalService.swift` — enum-namespace, 4 функции (`entryForToday`, `getOrCreateToday`, `setMood`, `setText`).
- `DailyFlow/Views/Journal/JournalView.swift` — корневой View, хедер + glue.
- `DailyFlow/Views/Journal/MoodPickerView.swift` — 5 тайлов с цифрами 1–5.
- `DailyFlow/Views/Journal/JournalEditorView.swift` — TextEditor + плейсхолдер + debounce.
- `DailyFlowTests/Services/JournalServiceTests.swift` — 15 тестов сервиса.

**Модифицировать:**
- `DailyFlow/Extensions/PreviewContainer.swift` — добавить кейсы `.emptyJournal`, `.moodOnly`, `.fullJournal`, `.longJournal` в `enum PreviewScenario`.
- `DailyFlow/App/ContentView.swift` — заменить placeholder для вкладки «Дневник» на `JournalView()`.
- `CLAUDE.md` — обновить разделы «Статус», «Структура файлов», «Выполненные фичи».

**Без изменений:**
- `DailyFlow/Models/JournalEntry.swift` — модель уже подходит.

---

## Task 1: `JournalService` — `entryForToday` (TDD)

**Files:**
- Create: `DailyFlow/Services/JournalService.swift`
- Create: `DailyFlowTests/Services/JournalServiceTests.swift`

- [ ] **Step 1: Write failing tests**

Создай `DailyFlowTests/Services/JournalServiceTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import DailyFlow

extension DailyFlowTests {
    @Suite("JournalService", .serialized) @MainActor
    struct JournalServiceTests {

        // MARK: — entryForToday

        @Test func entryForToday_returnsNil_whenNoEntry() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            #expect(JournalService.entryForToday(in: ctx) == nil)
        }

        @Test func entryForToday_returnsEntry_whenExistsForToday() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalEntry(date: .now, moodScore: 4, text: "test")
            ctx.insert(entry)
            try ctx.save()
            #expect(JournalService.entryForToday(in: ctx)?.id == entry.id)
        }

        @Test func entryForToday_returnsNil_whenEntryIsForYesterday() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
            let entry = JournalEntry(date: yesterday, moodScore: 3, text: "")
            ctx.insert(entry)
            try ctx.save()
            #expect(JournalService.entryForToday(in: ctx) == nil)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
set -o pipefail && xcodebuild -project DailyFlow.xcodeproj -scheme DailyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:DailyFlowTests/DailyFlow Tests/JournalService \
  test 2>&1 | xcbeautify
```

Expected: компиляция тестов падает с `cannot find 'JournalService' in scope`.

- [ ] **Step 3: Implement `JournalService.entryForToday`**

Создай `DailyFlow/Services/JournalService.swift`:

```swift
import Foundation
import SwiftData

enum JournalService {

    /// Возвращает запись за сегодня (по startOfDay) или nil если её нет.
    static func entryForToday(in ctx: ModelContext, now: Date = .now) -> JournalEntry? {
        let target = Calendar.current.startOfDay(for: now)
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.date == target }
        )
        return (try? ctx.fetch(descriptor))?.first
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Та же команда, что в Step 2. Expected: 3 теста проходят.

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Services/JournalService.swift DailyFlowTests/Services/JournalServiceTests.swift
git commit -m "feat(journal): add JournalService.entryForToday with tests

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: `JournalService` — `getOrCreateToday` (TDD)

**Files:**
- Modify: `DailyFlow/Services/JournalService.swift`
- Modify: `DailyFlowTests/Services/JournalServiceTests.swift`

- [ ] **Step 1: Add failing tests**

Добавь в `JournalServiceTests` после блока `entryForToday`:

```swift
        // MARK: — getOrCreateToday

        @Test func getOrCreateToday_createsWithDefaults_whenAbsent() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            #expect(entry.moodScore == 3)
            #expect(entry.text == "")
            #expect(entry.date == Calendar.current.startOfDay(for: .now))
        }

        @Test func getOrCreateToday_returnsExisting_andDoesNotDuplicate() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let first = JournalService.getOrCreateToday(in: ctx)
            let second = JournalService.getOrCreateToday(in: ctx)
            #expect(first.id == second.id)
            let all = (try? ctx.fetch(FetchDescriptor<JournalEntry>())) ?? []
            #expect(all.count == 1)
        }

        @Test func getOrCreateToday_dateIsAlwaysStartOfDay() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            // Симулируем «полдень» как now
            var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
            components.hour = 13
            components.minute = 27
            let noon = Calendar.current.date(from: components)!
            let entry = JournalService.getOrCreateToday(in: ctx, now: noon)
            #expect(entry.date == Calendar.current.startOfDay(for: noon))
        }
```

- [ ] **Step 2: Run to verify failure**

Та же команда. Expected: 3 новых теста падают (`'getOrCreateToday' is not a member of JournalService`).

- [ ] **Step 3: Implement**

Добавь в `JournalService` после `entryForToday`:

```swift
    /// Возвращает существующую запись или создаёт новую с дефолтами и инсертит в контекст.
    /// Дефолты: moodScore = 3, text = "".
    @discardableResult
    static func getOrCreateToday(in ctx: ModelContext, now: Date = .now) -> JournalEntry {
        if let existing = entryForToday(in: ctx, now: now) {
            return existing
        }
        let entry = JournalEntry(date: now)
        ctx.insert(entry)
        try? ctx.save()
        return entry
    }
```

- [ ] **Step 4: Run tests to pass**

Expected: все 6 тестов проходят.

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Services/JournalService.swift DailyFlowTests/Services/JournalServiceTests.swift
git commit -m "feat(journal): add getOrCreateToday with tests

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: `JournalService` — `setMood` (TDD)

**Files:**
- Modify: `DailyFlow/Services/JournalService.swift`
- Modify: `DailyFlowTests/Services/JournalServiceTests.swift`

- [ ] **Step 1: Add failing tests**

Добавь в `JournalServiceTests`:

```swift
        // MARK: — setMood

        @Test func setMood_createsEntry_andSetsScore_whenAbsent() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            JournalService.setMood(4, in: ctx)
            let entry = JournalService.entryForToday(in: ctx)
            #expect(entry?.moodScore == 4)
        }

        @Test func setMood_updatesScore_whenEntryExists() async throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            let originalUpdatedAt = entry.updatedAt
            try await Task.sleep(for: .milliseconds(10))
            JournalService.setMood(5, in: ctx)
            #expect(entry.moodScore == 5)
            #expect(entry.updatedAt > originalUpdatedAt)
        }

        @Test func setMood_isNoOp_whenSameScore() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            entry.moodScore = 3
            entry.updatedAt = Date(timeIntervalSince1970: 1_000_000)
            try ctx.save()
            JournalService.setMood(3, in: ctx)
            #expect(entry.moodScore == 3)
            #expect(entry.updatedAt == Date(timeIntervalSince1970: 1_000_000))
        }

        @Test func setMood_acceptsBoundaryValues() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            JournalService.setMood(1, in: ctx)
            #expect(JournalService.entryForToday(in: ctx)?.moodScore == 1)
            JournalService.setMood(5, in: ctx)
            #expect(JournalService.entryForToday(in: ctx)?.moodScore == 5)
        }
```

- [ ] **Step 2: Run to verify failure**

Expected: 4 новых теста падают на отсутствии `setMood`.

- [ ] **Step 3: Implement**

Добавь в `JournalService`:

```swift
    /// Устанавливает moodScore.
    /// Если значение совпадает с текущим — no-op (updatedAt не меняется).
    /// Если записи нет — создаёт через getOrCreateToday и сразу выставляет.
    static func setMood(_ score: Int, in ctx: ModelContext, now: Date = .now) {
        precondition((1...5).contains(score), "moodScore must be in 1...5")
        let entry = getOrCreateToday(in: ctx, now: now)
        guard entry.moodScore != score else { return }
        entry.moodScore = score
        entry.updatedAt = now
        try? ctx.save()
    }
```

- [ ] **Step 4: Run tests to pass**

Expected: все 10 тестов проходят.

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Services/JournalService.swift DailyFlowTests/Services/JournalServiceTests.swift
git commit -m "feat(journal): add setMood with no-op-on-same-value semantics

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: `JournalService` — `setText` (TDD)

**Files:**
- Modify: `DailyFlow/Services/JournalService.swift`
- Modify: `DailyFlowTests/Services/JournalServiceTests.swift`

- [ ] **Step 1: Add failing tests**

Добавь в `JournalServiceTests`:

```swift
        // MARK: — setText

        @Test func setText_createsEntry_whenTextNonEmpty_andAbsent() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            JournalService.setText("hello", in: ctx)
            let entry = JournalService.entryForToday(in: ctx)
            #expect(entry?.text == "hello")
            #expect(entry?.moodScore == 3)
        }

        @Test func setText_doesNotCreateEntry_whenTextEmpty_andAbsent() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            JournalService.setText("", in: ctx)
            #expect(JournalService.entryForToday(in: ctx) == nil)
        }

        @Test func setText_updatesText_whenEntryExists() async throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            let originalUpdatedAt = entry.updatedAt
            try await Task.sleep(for: .milliseconds(10))
            JournalService.setText("new text", in: ctx)
            #expect(entry.text == "new text")
            #expect(entry.moodScore == 3)
            #expect(entry.updatedAt > originalUpdatedAt)
        }

        @Test func setText_acceptsEmptyString_whenEntryExists() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            entry.text = "previous"
            try ctx.save()
            JournalService.setText("", in: ctx)
            #expect(entry.text == "")
        }

        @Test func setText_isNoOp_whenSameValue() throws {
            let container = try TestContainer.make()
            let ctx = container.mainContext
            let entry = JournalService.getOrCreateToday(in: ctx)
            entry.text = "stable"
            entry.updatedAt = Date(timeIntervalSince1970: 1_000_000)
            try ctx.save()
            JournalService.setText("stable", in: ctx)
            #expect(entry.text == "stable")
            #expect(entry.updatedAt == Date(timeIntervalSince1970: 1_000_000))
        }
```

- [ ] **Step 2: Run to verify failure**

Expected: 5 новых тестов падают на отсутствии `setText`.

- [ ] **Step 3: Implement**

Добавь в `JournalService`:

```swift
    /// Записывает text.
    /// Если запись отсутствует и text пустой — no-op (не плодим пустые записи).
    /// Если запись отсутствует и text не пустой — создаёт через getOrCreateToday и пишет text.
    /// Обновляет updatedAt только если значение реально изменилось.
    static func setText(_ text: String, in ctx: ModelContext, now: Date = .now) {
        if entryForToday(in: ctx, now: now) == nil, text.isEmpty {
            return
        }
        let entry = getOrCreateToday(in: ctx, now: now)
        guard entry.text != text else { return }
        entry.text = text
        entry.updatedAt = now
        try? ctx.save()
    }
```

- [ ] **Step 4: Run tests to pass**

Expected: все 15 тестов JournalService проходят. Ни один существующий тест Today/Habits не сломан (запусти полный пакет: убери `-only-testing` из команды).

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Services/JournalService.swift DailyFlowTests/Services/JournalServiceTests.swift
git commit -m "feat(journal): add setText with lazy-create + no-op semantics

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Расширить `PreviewContainer` журналскими сценариями

**Files:**
- Modify: `DailyFlow/Extensions/PreviewContainer.swift`

- [ ] **Step 1: Добавить enum-кейсы**

В `enum PreviewScenario` после `.longStreak` добавь:

```swift
    // Дневник:
    case emptyJournal
    case moodOnly
    case fullJournal
    case longJournal
```

- [ ] **Step 2: Реализовать сценарии в switch**

Добавь в `switch scenario` блока внутри `extension ModelContainer.preview` после `.longStreak`:

```swift
        case .emptyJournal:
            break

        case .moodOnly:
            ctx.insert(JournalEntry(date: today, moodScore: 4, text: ""))

        case .fullJournal:
            ctx.insert(JournalEntry(
                date: today,
                moodScore: 5,
                text: "Сегодня прошёл день в потоке. Завершил спецификацию журнала, прошлись по всем edge-кейсам, спокойно."
            ))

        case .longJournal:
            let longText = String(repeating: "Длинный текст записи. ", count: 100)
            ctx.insert(JournalEntry(date: today, moodScore: 3, text: longText))
```

- [ ] **Step 3: Сборка**

```bash
set -o pipefail && xcodebuild -project DailyFlow.xcodeproj -scheme DailyFlow \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | xcbeautify
```

Expected: `✅ build ok`.

- [ ] **Step 4: Commit**

```bash
git add DailyFlow/Extensions/PreviewContainer.swift
git commit -m "feat(journal): add preview scenarios for journal screen

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: `MoodPickerView`

**Files:**
- Create: `DailyFlow/Views/Journal/MoodPickerView.swift`

- [ ] **Step 1: Создать файл**

```swift
import SwiftUI

struct MoodPickerView: View {
    let selectedScore: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { score in
                MoodTile(score: score, isSelected: score == selectedScore)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(score) }
            }
        }
        .frame(height: 56)
    }
}

private struct MoodTile: View {
    let score: Int
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentPurple : Color.bgCard)
            Text("\(score)")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("None selected") {
    MoodPickerView(selectedScore: nil) { _ in }
        .padding(16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}

#Preview("Score 3 selected") {
    MoodPickerView(selectedScore: 3) { _ in }
        .padding(16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Сборка + лайф-цикл превью**

```bash
set -o pipefail && xcodebuild -project DailyFlow.xcodeproj -scheme DailyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | xcbeautify
```

Expected: `✅ build ok`. Открой превью в Xcode (или сделай скриншот через симулятор) и проверь визуально: 5 квадратов с цифрами, выбранный — фиолетовый.

- [ ] **Step 3: Commit**

```bash
git add DailyFlow/Views/Journal/MoodPickerView.swift
git commit -m "feat(journal): MoodPickerView — 5 numbered tiles 1-5

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: `JournalEditorView`

**Files:**
- Create: `DailyFlow/Views/Journal/JournalEditorView.swift`

- [ ] **Step 1: Создать файл**

```swift
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
```

- [ ] **Step 2: Сборка**

Та же команда сборки. Expected: `✅ build ok`. Если ругается на `ModelContainer.preview` в `#Preview` — оберни в `@MainActor` или используй `MainActor.assumeIsolated { ... }` в превью.

- [ ] **Step 3: Commit**

```bash
git add DailyFlow/Views/Journal/JournalEditorView.swift
git commit -m "feat(journal): JournalEditorView with debounced autosave

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: `JournalView` (корневой) + интеграция

**Files:**
- Create: `DailyFlow/Views/Journal/JournalView.swift`
- Modify: `DailyFlow/App/ContentView.swift`

- [ ] **Step 1: Создать `JournalView`**

```swift
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

            JournalEditorView(entry: entries.first) { newText in
                JournalService.setText(newText, in: ctx)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bgPrimary)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { dismissKeyboard() }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateCaption)
                .dfCaption()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateCaption: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "EEEE, d MMMM"
        return fmt.string(from: .now).uppercased()
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
```

- [ ] **Step 2: Подключить в `ContentView`**

В `DailyFlow/App/ContentView.swift` найди блок:

```swift
            placeholder
                .tabItem { Label("Дневник", systemImage: "note.text") }
```

Замени на:

```swift
            JournalView()
                .tabItem { Label("Дневник", systemImage: "note.text") }
```

- [ ] **Step 3: Сборка**

Та же команда. Expected: `✅ build ok`.

- [ ] **Step 4: Запуск симулятора, ручная проверка превью**

Проверь визуально (через `#Preview` в Xcode или запуск приложения):
1. Открыть «Дневник» — пустой, плейсхолдер виден.
2. Тапнуть «3» в MoodPicker — тайл подсветился фиолетовым, хаптика (если на устройстве).
3. Ввести текст — через ~1.5с после паузы запись сохранилась (закрыть-открыть экран → текст вернулся).
4. Тап «Готово» в keyboard toolbar — клавиатура скрылась.
5. Тап по фону экрана — клавиатура скрылась.
6. Перейти на другую вкладку и обратно — состояние сохранено.

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Views/Journal/JournalView.swift DailyFlow/App/ContentView.swift
git commit -m "feat(journal): JournalView root + wire into ContentView

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: Финальная верификация — лайн, формат, полный билд, все тесты

**Files:** none (проверка)

- [ ] **Step 1: swiftformat lint**

```bash
swiftformat --lint . 2>&1 | tail -20
```

Expected: `0 issues`. Если есть issues — применить:

```bash
swiftformat .
```

И снова прогнать `--lint`.

- [ ] **Step 2: swiftlint**

```bash
swiftlint
```

Expected: `0 violations` или близко к нему. Любые warnings из новых файлов — починить (типичное: отсутствующий final, force-unwrap, длинная строка).

- [ ] **Step 3: Полная сборка**

```bash
set -o pipefail && xcodebuild -project DailyFlow.xcodeproj -scheme DailyFlow \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  clean build 2>&1 | xcbeautify
```

Expected: `BUILD SUCCEEDED`, 0 warnings.

- [ ] **Step 4: Полный прогон тестов**

```bash
set -o pipefail && xcodebuild -project DailyFlow.xcodeproj -scheme DailyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test 2>&1 | xcbeautify
```

Expected:
- `JournalService` — 15 тестов passed.
- `HabitService` — 15 тестов passed (без регрессий).
- `TaskService` — 14 тестов passed (без регрессий).
- `DailyTask` — 3 теста passed.
- Итого: 47+ тестов passed, 0 failed.

- [ ] **Step 5: Если всё чисто — commit «verification»**

Если в Step 1 пришлось применять `swiftformat .` — закоммить отдельно:

```bash
git add -A
git commit -m "style: swiftformat fixes for journal screen

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

Если правок нет — пропустить.

---

## Task 10: Обновить `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Обновить раздел «Статус»**

Найди строку начинающуюся с `**Статус:**` и обнови:

Было:
```
**Статус:** 🟢 Phase 1 завершена. Phase 2 завершена. Экраны «Сегодня» и «Привычки» полностью реализованы: все View, сервисы, модели, расширения, тесты. Build succeeded 0 warnings. Следующий шаг — экраны «Дневник», «Инсайты» (нужны спеки).
```

Стало:
```
**Статус:** 🟢 Phase 1 завершена. Phase 2 завершена. Экраны «Сегодня», «Привычки» и «Дневник» полностью реализованы: все View, сервисы, модели, расширения, тесты. Build succeeded 0 warnings. Следующий шаг — экспорт в Obsidian (нужен спек) и экран «Инсайты» (нужен спек).
```

- [ ] **Step 2: Обновить «Структура файлов»**

В блоке диаграммы файлов в разделе `Views/`:

Было:
```
      Journal/                          # экран «Дневник» (отдельный спек)
```

Стало:
```
      Journal/
        JournalView.swift               # обёртка: хедер + MoodPicker + Editor
        MoodPickerView.swift            # 5 цифровых тайлов 1–5
        JournalEditorView.swift         # TextEditor с debounce-autosave
```

В блоке `Services/`:

Было:
```
      ObsidianService.swift             # экспорт .md через UIDocumentPickerViewController
```

Стало (добавь строчку перед `ObsidianService.swift`):
```
      JournalService.swift              # бизнес-логика дневника (enum-namespace, stateless)
      ObsidianService.swift             # экспорт .md через UIDocumentPickerViewController
```

В блоке `DailyFlowTests/Services/`:

Было:
```
  Services/HabitServiceTests.swift     # 15 тестов HabitService
```

Стало:
```
  Services/HabitServiceTests.swift     # 15 тестов HabitService
  Services/JournalServiceTests.swift   # 15 тестов JournalService
```

- [ ] **Step 3: Обновить «Выполненные фичи»**

Было:
```
- [ ] Экран «Дневник» (нужен спек)
```

Стало:
```
- [x] Экран «Дневник» — полностью реализован, build ok, lint clean, 15 тестов JournalService
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude-md): обновить статус после реализации экрана Дневник

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Acceptance Criteria (финальный чек)

После Task 10 убедись что выполнены все пункты из §9 спека:

1. ✅ Экран «Дневник» открывается из TabView (третья вкладка), placeholder заменён.
2. ✅ Хедер показывает дату через `.dfCaption()` (textGhost, ALL CAPS, letter-spacing 0.5pt).
3. ✅ MoodPicker — 5 тайлов высотой 56pt, цифры 1–5 в `.dfTitle`, выбранный = purple, невыбранный = bgCard.
4. ✅ TextEditor растягивается на оставшийся экран; пустой — плейсхолдер «Что сегодня было?» в textGhost.
5. ✅ Автосохранение: текст debounce 1.5с; mood мгновенно. Toast не показывается.
6. ✅ `onDisappear` flush'ит pending debounce.
7. ✅ Кнопка «Готово» в keyboard toolbar и тап по фону закрывают клавиатуру.
8. ✅ Lazy-создание: на пустой базе без действий запись НЕ создаётся.
9. ✅ Первая правка text → запись с moodScore=3, MoodPicker подсвечивает «3».
10. ✅ Cross-midnight НЕ обрабатывается.
11. ✅ Кнопка Obsidian отсутствует.
12. ✅ Динамический тип `.medium`–`.xxxLarge` читаемо (визуальная проверка превью с увеличенным шрифтом по желанию).
13. ✅ swiftformat / swiftlint clean, build clean.
14. ✅ Все 15 JournalService-тестов проходят, существующие не сломаны.
15. ✅ CLAUDE.md обновлён.

---

## Если что-то пошло не так

- **`@Query` не возвращает запись после insert.** Убеди что вызвал `try? ctx.save()` после `ctx.insert(...)`. SwiftData в iOS 26 обычно сразу видит изменения, но `save()` гарантирует persisting в `@Query`.
- **`#Predicate` падает на сравнении `Date`.** SwiftData требует точное равенство; `target` должен быть `let` локальной переменной (захват в predicate).
- **`Task.sleep` в тестах.** Используй `try await Task.sleep(for: .milliseconds(N))`. Тест должен быть `async throws`.
- **`MoodPickerView` тайлы не одной ширины.** Убеди что у `MoodTile` стоит `.frame(maxWidth: .infinity)` — это даёт каждому квадрату равную долю.
- **Плейсхолдер виден поверх текста.** `if text.isEmpty` управляет показом; `.allowsHitTesting(false)` не даёт ему перехватывать тапы.
- **TextEditor подсвечивается белым фоном.** Применяй `.scrollContentBackground(.hidden)` ПЕРЕД `.background(Color.bgCard)`.
- **Тест `setMood_isNoOp_whenSameScore` нестабильный.** SwiftData может пересчитать `updatedAt` при `save()`. Проверка через жёстко заданный `Date(timeIntervalSince1970:)` — самый надёжный способ.
