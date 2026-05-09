# Экран «Привычки» — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Реализовать экран «Привычки» с карточками, PixelGrid за 7 дней, toggle по карточке, drag-to-reorder, добавлением и редактированием привычек через sheet.

**Architecture:** Pure SwiftUI + `@Query(sort: \.sortOrder)` на `[Habit]` в `HabitsView`, `List` с `.onMove` для drag-to-reorder, `HabitService` enum-namespace для всей бизнес-логики. Модели `Habit` и `HabitLog` уже готовы — не трогать.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing

---

## Карта файлов

| Файл | Действие | Ответственность |
|---|---|---|
| `DailyFlow/Extensions/ColorExtensions.swift` | Modify | Добавить `init(hex: String)` |
| `DailyFlow/Services/HabitService.swift` | Create | Вся бизнес-логика привычек |
| `DailyFlow/Views/Habits/PixelGridView.swift` | Create | 7 квадратов 28×28, последние 7 дней |
| `DailyFlow/Views/Habits/AddHabitSheet.swift` | Create | Sheet создания/редактирования привычки |
| `DailyFlow/Views/Habits/HabitCardView.swift` | Create | Карточка с toggle, streak, PixelGrid |
| `DailyFlow/Views/Habits/HabitsView.swift` | Create | List + @Query + drag + ghost-кнопка |
| `DailyFlow/Extensions/PreviewContainer.swift` | Modify | Добавить 3 сценария для привычек |
| `DailyFlow/App/ContentView.swift` | Modify | Подключить `HabitsView()` |
| `DailyFlowTests/Services/HabitServiceTests.swift` | Create | 13 тестов Swift Testing |
| `DailyFlow/CLAUDE.md` | Modify | Статус + выполненные фичи |

---

## Task 1: `Color(hex: String)` — поддержка строковых hex

`Habit.colorHex` — это `String` (`"2DD4A0"`). Текущий `ColorExtensions.swift` имеет только `init(hex: UInt32)`. `PixelGridView` и `HabitCardView` нуждаются в `Color(hex: String)`.

**Files:**
- Modify: `DailyFlow/Extensions/ColorExtensions.swift`

- [ ] **Step 1: Добавить `init(hex: String)` в ColorExtensions.swift**

Открыть `DailyFlow/Extensions/ColorExtensions.swift`. Добавить после `init(hex: UInt32)`:

```swift
import SwiftUI

extension Color {
    static let bgPrimary = Color(hex: 0x0D0D0D)
    static let bgCard = Color(hex: 0x1A1A1A)
    static let accentTeal = Color(hex: 0x2DD4A0)
    static let accentAmber = Color(hex: 0xF0A23B)
    static let accentPurple = Color(hex: 0x9B8AE8)
    static let textPrimary = Color(hex: 0xF2F2F2)
    static let textSecondary = Color(hex: 0x888888)
    static let textGhost = Color(hex: 0x666666)

    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    init(hex string: String) {
        let cleaned = string.hasPrefix("#") ? String(string.dropFirst()) : string
        self.init(hex: UInt32(cleaned, radix: 16) ?? 0)
    }
}
```

- [ ] **Step 2: Собрать проект — убедиться, что нет ошибок**

```bash
/build
```

Ожидание: `BUILD SUCCEEDED` без warnings.

- [ ] **Step 3: Закоммитить**

```bash
git add DailyFlow/Extensions/ColorExtensions.swift
git commit -m "feat(extensions): добавить Color(hex: String) для Habit.colorHex"
```

---

## Task 2: `HabitServiceTests` — написать тесты первыми (TDD)

Написать тесты ДО реализации. Они будут падать — это нормально.

**Files:**
- Create: `DailyFlowTests/Services/HabitServiceTests.swift`

- [ ] **Step 1: Создать файл тестов**

Создать `DailyFlowTests/Services/HabitServiceTests.swift` с содержимым:

```swift
import Testing
import SwiftData
@testable import DailyFlow

@Suite("HabitService") @MainActor
struct HabitServiceTests {

    // MARK: — add

    @Test func add_returnsNilForEmptyName() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        #expect(HabitService.add(name: "   ", colorHex: "2DD4A0", in: ctx) == nil)
    }

    @Test func add_assignsIncrementingSortOrder() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h1 = HabitService.add(name: "First", colorHex: "2DD4A0", in: ctx)
        let h2 = HabitService.add(name: "Second", colorHex: "F0A23B", in: ctx)
        #expect(h1?.sortOrder == 0)
        #expect(h2?.sortOrder == 1)
    }

    // MARK: — toggleToday / isDone

    @Test func toggleToday_createsLog() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.toggleToday(habit, in: ctx)
        #expect(habit.logs.count == 1)
        #expect(HabitService.isDone(habit, on: .now))
    }

    @Test func toggleToday_removesLogOnSecondCall() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.toggleToday(habit, in: ctx)
        HabitService.toggleToday(habit, in: ctx)
        #expect(habit.logs.isEmpty)
        #expect(!HabitService.isDone(habit, on: .now))
    }

    @Test func toggleToday_idempotentOnThirdCall() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.toggleToday(habit, in: ctx)
        HabitService.toggleToday(habit, in: ctx)
        HabitService.toggleToday(habit, in: ctx)
        #expect(habit.logs.count == 1)
    }

    @Test func isDone_returnsFalseWhenNoLog() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        #expect(!HabitService.isDone(habit, on: .now))
    }

    // MARK: — streak

    @Test func streak_returnsZeroAndInactiveWhenNeverDone() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        let result = HabitService.streak(for: habit, relativeTo: .now)
        #expect(result.value == 0)
        #expect(!result.isActive)
    }

    @Test func streak_returnsOneAndActiveWhenDoneToday() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.toggleToday(habit, in: ctx)
        let result = HabitService.streak(for: habit, relativeTo: .now)
        #expect(result.value == 1)
        #expect(result.isActive)
    }

    @Test func streak_returnsYesterdayCountAndInactiveWhenNotDoneToday() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        let yesterday = Calendar.current.date(
            byAdding: .day, value: -1,
            to: Calendar.current.startOfDay(for: .now)
        )!
        ctx.insert(HabitLog(date: yesterday, habit: habit))
        let result = HabitService.streak(for: habit, relativeTo: .now)
        #expect(result.value == 1)
        #expect(!result.isActive)
    }

    @Test func streak_breaksOnMissedDay() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        let today = Calendar.current.startOfDay(for: .now)
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        // Сделано сегодня и два дня назад, вчера — пропуск
        ctx.insert(HabitLog(date: today, habit: habit))
        ctx.insert(HabitLog(date: twoDaysAgo, habit: habit))
        let result = HabitService.streak(for: habit, relativeTo: .now)
        #expect(result.value == 1)   // только сегодня, вчера — разрыв
        #expect(result.isActive)
    }

    // MARK: — reorder

    @Test func reorder_updatesSortOrder() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h1 = Habit(name: "A", colorHex: "2DD4A0", sortOrder: 0)
        let h2 = Habit(name: "B", colorHex: "F0A23B", sortOrder: 1)
        let h3 = Habit(name: "C", colorHex: "9B8AE8", sortOrder: 2)
        [h1, h2, h3].forEach { ctx.insert($0) }
        // Переместить первый элемент в конец: [h1,h2,h3] → [h2,h3,h1]
        HabitService.reorder([h1, h2, h3], from: IndexSet(integer: 0), to: 3, in: ctx)
        #expect(h2.sortOrder == 0)
        #expect(h3.sortOrder == 1)
        #expect(h1.sortOrder == 2)
    }

    // MARK: — delete

    @Test func delete_cascadesLogs() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let habit = Habit(name: "Test", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(habit)
        HabitService.toggleToday(habit, in: ctx)
        #expect(habit.logs.count == 1)
        HabitService.delete(habit, in: ctx)
        let remaining = try ctx.fetch(FetchDescriptor<HabitLog>())
        #expect(remaining.isEmpty)
    }
}
```

- [ ] **Step 2: Убедиться, что тесты НЕ компилируются (HabitService не существует)**

```bash
/build
```

Ожидание: ошибки компиляции вида `cannot find 'HabitService' in scope`.

---

## Task 3: `HabitService` — реализация (TDD green)

**Files:**
- Create: `DailyFlow/Services/HabitService.swift`

- [ ] **Step 1: Создать HabitService.swift**

```swift
import Foundation
import SwiftData

enum HabitService {

    @discardableResult
    static func add(name: String, colorHex: String, in ctx: ModelContext) -> Habit? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = (try? ctx.fetch(FetchDescriptor<Habit>())) ?? []
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let habit = Habit(name: trimmed, colorHex: colorHex, sortOrder: nextOrder)
        ctx.insert(habit)
        try? ctx.save()
        return habit
    }

    static func update(_ habit: Habit, name: String, colorHex: String, in ctx: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { habit.name = trimmed }
        habit.colorHex = colorHex
        try? ctx.save()
    }

    static func delete(_ habit: Habit, in ctx: ModelContext) {
        ctx.delete(habit)
        try? ctx.save()
    }

    static func reorder(_ habits: [Habit], from source: IndexSet, to dest: Int, in ctx: ModelContext) {
        var reordered = habits
        reordered.move(fromOffsets: source, toOffset: dest)
        for (i, habit) in reordered.enumerated() {
            habit.sortOrder = i
        }
        try? ctx.save()
    }

    static func toggleToday(_ habit: Habit, in ctx: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        if let existing = habit.logs.first(where: { $0.date == today }) {
            ctx.delete(existing)
        } else {
            ctx.insert(HabitLog(date: today, habit: habit))
        }
        try? ctx.save()
    }

    static func isDone(_ habit: Habit, on date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return habit.logs.contains { $0.date == day }
    }

    static func streak(for habit: Habit, relativeTo date: Date) -> (value: Int, isActive: Bool) {
        let today = Calendar.current.startOfDay(for: date)
        if isDone(habit, on: today) {
            return (consecutiveDays(for: habit, endingAt: today), true)
        }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        return (consecutiveDays(for: habit, endingAt: yesterday), false)
    }

    private static func consecutiveDays(for habit: Habit, endingAt date: Date) -> Int {
        var count = 0
        var current = date
        while isDone(habit, on: current) {
            count += 1
            current = Calendar.current.date(byAdding: .day, value: -1, to: current)!
        }
        return count
    }
}
```

- [ ] **Step 2: Запустить тесты**

```bash
/build
```

Затем запустить тесты через Xcode (Cmd+U) или:
```bash
xcodebuild test -scheme DailyFlow -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | grep -E "(Test|PASS|FAIL|error:)"
```

Ожидание: все 13 тестов зелёные.

- [ ] **Step 3: Закоммитить**

```bash
git add DailyFlow/Services/HabitService.swift DailyFlowTests/Services/HabitServiceTests.swift
git commit -m "feat(habits): реализовать HabitService + тесты (13 green)"
```

---

## Task 4: `PixelGridView` — 7 квадратов за 7 дней

**Files:**
- Create: `DailyFlow/Views/Habits/PixelGridView.swift`

- [ ] **Step 1: Создать PixelGridView.swift**

```swift
import SwiftUI
import SwiftData

struct PixelGridView: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 4) {
            ForEach(lastSevenDays, id: \.self) { date in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        HabitService.isDone(habit, on: date)
                            ? Color(hex: habit.colorHex)
                            : Color(hex: "333333")
                    )
                    .frame(width: 28, height: 28)
            }
        }
    }

    private var lastSevenDays: [Date] {
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<7).reversed().map {
            Calendar.current.date(byAdding: .day, value: -$0, to: today)!
        }
    }
}

#Preview("Без выполнений") {
    let habit = Habit(name: "Медитация", colorHex: "2DD4A0", sortOrder: 0)
    return PixelGridView(habit: habit)
        .padding()
        .background(Color.bgCard)
        .preferredColorScheme(.dark)
}

#Preview("С выполнениями") {
    PixelGridView(habit: Habit(name: "Спорт", colorHex: "F0A23B", sortOrder: 0))
        .padding()
        .background(Color.bgCard)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Собрать и проверить preview**

```bash
/build
```

Ожидание: BUILD SUCCEEDED. Проверить `#Preview` в Xcode Canvas — должны быть видны 7 квадратов, левые серые.

- [ ] **Step 3: Закоммитить**

```bash
git add DailyFlow/Views/Habits/PixelGridView.swift
git commit -m "feat(habits): реализовать PixelGridView"
```

---

## Task 5: `AddHabitSheet` — sheet создания и редактирования привычки

**Files:**
- Create: `DailyFlow/Views/Habits/AddHabitSheet.swift`

- [ ] **Step 1: Создать AddHabitSheet.swift**

```swift
import SwiftUI

struct AddHabitSheet: View {
    let habit: Habit?
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedHex: String
    @FocusState private var isFocused: Bool

    private let colorOptions = ["2DD4A0", "F0A23B", "9B8AE8"]

    init(habit: Habit?, onSave: @escaping (String, String) -> Void) {
        self.habit = habit
        self.onSave = onSave
        _name = State(initialValue: habit?.name ?? "")
        _selectedHex = State(initialValue: habit?.colorHex ?? "2DD4A0")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 32) {
                TextField("Название привычки", text: $name)
                    .dfBody()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.bgCard, in: .rect(cornerRadius: 12))

                HStack(spacing: 12) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Button {
                            selectedHex = hex
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 32, height: 32)
                                    .opacity(selectedHex == hex ? 1.0 : 0.4)
                                if selectedHex == hex {
                                    Circle()
                                        .strokeBorder(Color(hex: hex), lineWidth: 2)
                                        .frame(width: 40, height: 40)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgPrimary)
            .navigationTitle(habit == nil ? "Новая привычка" : "Изменить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(habit == nil ? "Добавить" : "Сохранить") {
                        Haptics.tap(.light)
                        onSave(name, selectedHex)
                        dismiss()
                    }
                    .foregroundStyle(Color.accentTeal)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

#Preview("Создание") {
    AddHabitSheet(habit: nil) { _, _ in }
        .preferredColorScheme(.dark)
}

#Preview("Редактирование") {
    AddHabitSheet(
        habit: Habit(name: "Медитация", colorHex: "F0A23B", sortOrder: 0)
    ) { _, _ in }
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Собрать и проверить preview**

```bash
/build
```

Ожидание: BUILD SUCCEEDED. В preview «Создание» — пустое поле + 3 цветных круга (первый активен). В preview «Редактирование» — заполненное поле, активен amber.

- [ ] **Step 3: Закоммитить**

```bash
git add DailyFlow/Views/Habits/AddHabitSheet.swift
git commit -m "feat(habits): реализовать AddHabitSheet"
```

---

## Task 6: `HabitCardView` — карточка привычки

**Files:**
- Create: `DailyFlow/Views/Habits/HabitCardView.swift`

- [ ] **Step 1: Создать HabitCardView.swift**

```swift
import SwiftUI
import SwiftData

struct HabitCardView: View {
    let habit: Habit
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var isDoneToday: Bool {
        HabitService.isDone(habit, on: .now)
    }

    private var streakResult: (value: Int, isActive: Bool) {
        HabitService.streak(for: habit, relativeTo: .now)
    }

    private var accentColor: Color {
        Color(hex: habit.colorHex)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(habit.name).dfBody()
                PixelGridView(habit: habit)
            }
            Spacer()
            Text("\(streakResult.value)")
                .font(.system(size: 21, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(streakResult.isActive ? accentColor : Color.textSecondary)
                .animation(.easeInOut(duration: 0.2), value: streakResult.isActive)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            isDoneToday ? accentColor.opacity(0.08) : Color.bgCard,
            in: .rect(cornerRadius: 12)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 4)
                .opacity(isDoneToday ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isDoneToday)
        }
        .animation(.easeInOut(duration: 0.2), value: isDoneToday)
        .contentShape(.rect)
        .onTapGesture {
            let wasActive = isDoneToday
            onToggle()
            Haptics.tap(wasActive ? .light : .medium)
        }
        .contextMenu {
            Button("Изменить") { onEdit() }
            Button("Удалить", role: .destructive) {
                Haptics.tap(.heavy)
                onDelete()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Haptics.tap(.heavy)
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

#Preview("Не выполнена") {
    let habit = Habit(name: "Медитация", colorHex: "2DD4A0", sortOrder: 0)
    return HabitCardView(habit: habit, onToggle: {}, onEdit: {}, onDelete: {})
        .padding()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}

#Preview("Выполнена сегодня") {
    let container = ModelContainer.preview(.empty)
    let habit = Habit(name: "Спорт", colorHex: "F0A23B", sortOrder: 0)
    let today = Calendar.current.startOfDay(for: .now)
    container.mainContext.insert(habit)
    container.mainContext.insert(HabitLog(date: today, habit: habit))
    return HabitCardView(habit: habit, onToggle: {}, onEdit: {}, onDelete: {})
        .padding()
        .background(Color.bgPrimary)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Собрать и проверить preview**

```bash
/build
```

Ожидание: BUILD SUCCEEDED. Preview «Не выполнена» — тёмная карточка, серая цифра 0. Preview «Выполнена» — card с цветным бордером слева, цветная цифра 1.

- [ ] **Step 3: Закоммитить**

```bash
git add DailyFlow/Views/Habits/HabitCardView.swift
git commit -m "feat(habits): реализовать HabitCardView"
```

---

## Task 7: `PreviewContainer` — добавить сценарии для привычек

**Files:**
- Modify: `DailyFlow/Extensions/PreviewContainer.swift`

- [ ] **Step 1: Добавить новые случаи в `PreviewScenario` и `ModelContainer.preview`**

Открыть `DailyFlow/Extensions/PreviewContainer.swift`. Добавить три новых case в `PreviewScenario` и соответствующие ветки в `switch`:

```swift
import SwiftData
import SwiftUI

enum PreviewScenario {
    case empty
    case onlyFocus
    case mixed
    case withRollover
    case editingFirst
    // Привычки:
    case threeHabits
    case allHabitsDoneToday
    case longStreak
}

extension ModelContainer {
    @MainActor
    static func preview(_ scenario: PreviewScenario) -> ModelContainer {
        let schema = Schema([DailyTask.self, Habit.self, HabitLog.self, JournalEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: schema, configurations: [config])
        let ctx = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)

        switch scenario {
        case .empty:
            break

        case .onlyFocus:
            ctx.insert(DailyTask(title: "Сделать архитектуру экрана", date: today, isFocus: true))

        case .mixed:
            ctx.insert(DailyTask(title: "Спроектировать базу данных", date: today, isFocus: true))
            ctx.insert(DailyTask(title: "Написать тесты сервиса", date: today))
            ctx.insert(DailyTask(title: "Проверить цветовые токены", date: today))
            let done = DailyTask(title: "Выполненная задача", date: today)
            done.isCompleted = true
            done.completedAt = .now
            ctx.insert(done)

        case .withRollover:
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            ctx.insert(DailyTask(title: "Не перенёс вчера", date: yesterday))
            ctx.insert(DailyTask(title: "Ещё одна старая задача", date: yesterday))
            ctx.insert(DailyTask(title: "Задача сегодня", date: today))

        case .editingFirst:
            ctx.insert(DailyTask(title: "Задача в режиме редактирования", date: today))

        case .threeHabits:
            let h1 = Habit(name: "Медитация", colorHex: "2DD4A0", sortOrder: 0)
            let h2 = Habit(name: "Спорт", colorHex: "F0A23B", sortOrder: 1)
            let h3 = Habit(name: "Чтение", colorHex: "9B8AE8", sortOrder: 2)
            [h1, h2, h3].forEach { ctx.insert($0) }
            // h1 выполнена сегодня
            ctx.insert(HabitLog(date: today, habit: h1))
            // h2 выполнена вчера (стрик 1, серый)
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            ctx.insert(HabitLog(date: yesterday, habit: h2))

        case .allHabitsDoneToday:
            let h1 = Habit(name: "Медитация", colorHex: "2DD4A0", sortOrder: 0)
            let h2 = Habit(name: "Спорт", colorHex: "F0A23B", sortOrder: 1)
            let h3 = Habit(name: "Чтение", colorHex: "9B8AE8", sortOrder: 2)
            [h1, h2, h3].forEach { ctx.insert($0) }
            [h1, h2, h3].forEach { ctx.insert(HabitLog(date: today, habit: $0)) }

        case .longStreak:
            let h1 = Habit(name: "Медитация", colorHex: "2DD4A0", sortOrder: 0)
            let h2 = Habit(name: "Спорт", colorHex: "F0A23B", sortOrder: 1)
            ctx.insert(h1); ctx.insert(h2)
            // h1: стрик 7 дней подряд включая сегодня
            for i in 0..<7 {
                let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
                ctx.insert(HabitLog(date: date, habit: h1))
            }
            // h2: стрик 3 дня, но сегодня не выполнена (серая цифра 3)
            for i in 1...3 {
                let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
                ctx.insert(HabitLog(date: date, habit: h2))
            }
        }

        return container
    }
}
```

- [ ] **Step 2: Собрать проект**

```bash
/build
```

Ожидание: BUILD SUCCEEDED.

- [ ] **Step 3: Закоммитить**

```bash
git add DailyFlow/Extensions/PreviewContainer.swift
git commit -m "feat(preview): добавить сценарии для экрана Привычки"
```

---

## Task 8: `HabitsView` — главный экран + подключение в ContentView

**Files:**
- Create: `DailyFlow/Views/Habits/HabitsView.swift`
- Modify: `DailyFlow/App/ContentView.swift`

- [ ] **Step 1: Создать HabitsView.swift**

```swift
import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    @State private var showAdd = false
    @State private var editingHabit: Habit?

    var body: some View {
        List {
            headerRow
            ForEach(habits) { habit in
                HabitCardView(
                    habit: habit,
                    onToggle: { HabitService.toggleToday(habit, in: ctx) },
                    onEdit:   { editingHabit = habit },
                    onDelete: { HabitService.delete(habit, in: ctx) }
                )
                .listRowBackground(Color.bgPrimary)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onMove { HabitService.reorder(habits, from: $0, to: $1, in: ctx) }
            ghostAddRow
        }
        .listStyle(.plain)
        .background(Color.bgPrimary)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
        .sheet(isPresented: $showAdd) {
            AddHabitSheet(habit: nil) { name, hex in
                HabitService.add(name: name, colorHex: hex, in: ctx)
            }
        }
        .sheet(item: $editingHabit) { habit in
            AddHabitSheet(habit: habit) { name, hex in
                HabitService.update(habit, name: name, colorHex: hex, in: ctx)
            }
        }
    }

    private var headerRow: some View {
        Text("Привычки")
            .dfTitle()
            .listRowBackground(Color.bgPrimary)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
    }

    private var ghostAddRow: some View {
        Button { showAdd = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .foregroundStyle(Color.accentTeal)
                    .frame(width: 16, height: 16)
                Text("Добавить привычку")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.accentTeal)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.bgPrimary)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

#Preview("Пустой") {
    HabitsView()
        .modelContainer(.preview(.empty))
        .preferredColorScheme(.dark)
}

#Preview("Три привычки") {
    HabitsView()
        .modelContainer(.preview(.threeHabits))
        .preferredColorScheme(.dark)
}

#Preview("Все выполнены") {
    HabitsView()
        .modelContainer(.preview(.allHabitsDoneToday))
        .preferredColorScheme(.dark)
}

#Preview("Длинный стрик") {
    HabitsView()
        .modelContainer(.preview(.longStreak))
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Подключить HabitsView в ContentView**

Открыть `DailyFlow/App/ContentView.swift`. Заменить первый `placeholder` на `HabitsView()`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Сегодня", systemImage: "calendar") }
            HabitsView()
                .tabItem { Label("Привычки", systemImage: "square.grid.2x2") }
            placeholder
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
```

- [ ] **Step 3: Собрать проект**

```bash
/build
```

Ожидание: BUILD SUCCEEDED без warnings.

- [ ] **Step 4: Прогнать линтер**

```bash
/lint
```

Ожидание: 0 ошибок, допустимы предупреждения о длине строк.

- [ ] **Step 5: Запустить симулятор и проверить экран «Привычки»**

```bash
/sim
```

Проверить в симуляторе (iPhone 16 Pro, iOS 26):

**Чеклист проверки:**
- [ ] Вкладка «Привычки» открывается, фон `#0D0D0D`
- [ ] Пустой экран: только заголовок «Привычки» и ghost-кнопка «Добавить привычку»
- [ ] Тап на ghost-кнопку открывает sheet
- [ ] Sheet: TextField автофокусируется, видны 3 цветных круга
- [ ] Ввести название, нажать «Добавить» → карточка появляется в списке
- [ ] Тап по карточке → карточка меняет стиль на акцентный (цветной бордер слева)
- [ ] Повторный тап → стиль возвращается к `.dfCard()`
- [ ] PixelGrid: последний квадрат закрашивается цветом привычки при выполнении
- [ ] Цифра стрика: цветная когда выполнено, серая когда нет
- [ ] Drag-handle видны справа от каждой карточки
- [ ] Drag карточки перегруппировывает список
- [ ] Long-press → contextMenu «Изменить» / «Удалить»
- [ ] «Изменить» открывает sheet с заполненными полями
- [ ] «Удалить» удаляет карточку
- [ ] Swipe влево → кнопка «Удалить» → удаление

- [ ] **Step 6: Закоммитить**

```bash
git add DailyFlow/Views/Habits/HabitsView.swift DailyFlow/App/ContentView.swift
git commit -m "feat(habits): реализовать HabitsView, подключить в ContentView"
```

---

## Task 9: Обновить `CLAUDE.md`

**Files:**
- Modify: `DailyFlow/CLAUDE.md`

- [ ] **Step 1: Обновить раздел «Статус»**

Найти строку `**Статус:**` и заменить на:

```
**Статус:** 🟢 Phase 1 завершена. Phase 2 завершена. Экраны «Сегодня» и «Привычки» полностью реализованы: все View, сервисы, модели, расширения, тесты. Build succeeded 0 warnings. Следующий шаг — экраны «Дневник», «Инсайты» (нужны спеки).
```

- [ ] **Step 2: Обновить раздел «Структура файлов» — секция Views/Habits**

Заменить заглушки:

```
    Views/
      Habits/
        HabitsView.swift           # List + @Query + drag + ghost-кнопка добавления
        HabitCardView.swift        # карточка: toggle, streak, PixelGrid, contextMenu
        PixelGridView.swift        # 7 квадратов 28×28, последние 7 дней
        AddHabitSheet.swift        # sheet создания/редактирования привычки
```

- [ ] **Step 3: Добавить в «Структура файлов» — Services**

```
    Services/
      TaskService.swift            # бизнес-логика задач
      HabitService.swift           # бизнес-логика привычек
```

- [ ] **Step 4: Обновить раздел «Выполненные фичи»**

```
- [x] Экран «Сегодня» — полностью реализован, build ok, lint clean, 12 тестов
- [x] Экран «Привычки» — полностью реализован, build ok, lint clean, 13 тестов
```

- [ ] **Step 5: Закоммитить**

```bash
git add DailyFlow/CLAUDE.md
git commit -m "docs(claude-md): обновить статус после реализации экрана Привычки"
```

---

## Итоговая проверка

- [ ] Все 13 тестов зелёные: `xcodebuild test ...`
- [ ] `/build` — BUILD SUCCEEDED, 0 warnings
- [ ] `/lint` — 0 ошибок
- [ ] Все 4 `#Preview` в HabitsView работают в Xcode Canvas
- [ ] Чеклист симулятора пройден (Task 8, Step 5)

---

## Известные ограничения

- **Drag handles в edit mode**: `swipeActions` и drag могут конфликтовать на iOS 26 — проверить в симуляторе. Если swipe не работает, вынести drag-to-reorder за кнопку «Изменить порядок» (EditButton в NavigationStack).
- **Обновление PixelGrid**: SwiftData `@Model` использует `@Observable` — изменение `habit.logs` должно автоматически перерисовывать `PixelGridView`. Если этого не происходит, добавить `@Bindable var habit: Habit` вместо `let habit: Habit` в `HabitCardView` и `PixelGridView`.
