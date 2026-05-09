# Insights Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Реализовать четвёртый экран DailyFlow — «Инсайты» — с тремя метриками-процентами (задачи, привычки, настроение), топ-3 текущих стриков и гистограммой настроения за последние 7 дней. Empty state до накопления 3 дней данных.

**Architecture:** Pure SwiftUI + `@Query` + `InsightsService`-namespace, без ViewModel. Двухслойная View `InsightsView` (scenePhase + `.id(dateAnchor)`) → `InsightsContentView` (рендер). Сервис — stateless `enum` с 6 чистыми функциями, принимающими `today: Date` и `ModelContext`. UI — 4 переиспользуемых компонента + корневой контент-вью + empty-state.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (`@Model`/`@Query`), Swift Charts (`BarMark`), Swift Testing (in-memory `ModelContainer`), iOS 26+. Без сторонних SPM-зависимостей.

**Spec:** `docs/superpowers/specs/2026-05-10-insights-screen-design.md`

---

## Pre-flight: Research Apple-документации

### Task 0: Research Swift Charts iOS 26 поведение пустых слотов

**Цель:** До начала реализации `MoodChartView` (Task 8) убедиться, что подход «не добавлять `BarMark` для дня без записи» сохраняет позиционирование оси X на iOS 26. Если нет — выбрать fallback заранее.

**Files:** none (research only)

- [ ] **Step 1: Прочитать Apple Docs**

Проверить страницы:
- `Charts.BarMark` — поведение при отсутствии данных для одной из категорий X.
- `Charts.AxisMarks(values:)` — гарантирует ли явное `values: [Date]` фиксированные позиции на оси.
- `Charts.chartXScale(domain:)` — взаимодействие с `unit: .day` в `BarMark.x`.

Ключевой вопрос: **«Если series длиной 7 содержит 5 точек с данными и 2 пустых дня, останутся ли пустые слоты видимыми, или ось X схлопнется?»**

- [ ] **Step 2: Записать выводы**

Создать ремарку в формате:

```
RESEARCH: Swift Charts iOS 26 — пустые слоты
- Подход A (не добавлять Mark): работает / не работает
- Подход B (chartXScale(domain:)): нужен / не нужен
- Подход C (RectangleMark высоты 0): запасной вариант — да / нет
- Финальное решение для Task 8: <выбор>
```

Записать в комментарий внутри `MoodChartView.swift` (создать заранее как заглушку с этим комментарием) или в комментарий в начало этой задачи в плане.

- [ ] **Step 3: Если ничего из A/B не работает — пометить риск**

Если оба подхода не дают пустых слотов — записать в `CLAUDE.md` → «Известные проблемы» строку: «Swift Charts iOS 26: пустые слоты не работают штатно, в `MoodChartView` использован fallback через `RectangleMark` высоты 0 / ручную HStack-реализацию».

Выбор fallback (если до этого дойдёт): **HStack из 7 `Capsule()`-баров** — проще и надёжнее, чем хаки вокруг Charts.

- [ ] **Step 4: Не коммитить**

Это research-задача. Никаких изменений в коде, кроме (опционально) комментариев. Коммита нет.

---

## Phase 1: Сервисный слой (TDD)

### Task 1: Каркас `InsightsService` и тестового сьюта

**Files:**
- Create: `DailyFlow/Services/InsightsService.swift`
- Create: `DailyFlowTests/Services/InsightsServiceTests.swift`

- [ ] **Step 1: Создать пустой сервис**

Содержимое `DailyFlow/Services/InsightsService.swift`:

```swift
import Foundation
import SwiftData

enum InsightsService {
    // Реализация по плану 2026-05-10-insights-screen.md
}
```

- [ ] **Step 2: Создать пустой тестовый сьют**

Содержимое `DailyFlowTests/Services/InsightsServiceTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import DailyFlow

extension DailyFlowTests {
@Suite("InsightsService", .serialized) @MainActor
struct InsightsServiceTests {

    // MARK: — Helpers

    /// Фиксированная "сегодняшняя" дата для всех тестов: 2026-05-10 00:00 UTC.
    /// Гарантирует детерминированность независимо от часов прогона.
    static let today: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 10
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar.current.date(from: components)!
    }()

    /// Возвращает startOfDay для today + offsetDays (offsetDays может быть отрицательным).
    static func day(_ offsetDays: Int) -> Date {
        let raw = Calendar.current.date(byAdding: .day, value: offsetDays, to: today)!
        return Calendar.current.startOfDay(for: raw)
    }
}
}
```

- [ ] **Step 3: Собрать проект и убедиться, что нет ошибок**

Run: `/build`
Expected: `✅ build ok`. Тестовый сьют пуст, но компилируется.

- [ ] **Step 4: Прогнать тестовый сьют**

Run:
```bash
set -o pipefail && xcodebuild test \
  -project DailyFlow.xcodeproj \
  -scheme DailyFlow \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:DailyFlowTests/InsightsServiceTests \
  | xcbeautify
```
Expected: 0 tests run, build succeeded, no failures.

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Services/InsightsService.swift DailyFlowTests/Services/InsightsServiceTests.swift
git commit -m "feat(insights): scaffold InsightsService and test suite

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: `tasksRate` (4 теста)

**Files:**
- Modify: `DailyFlow/Services/InsightsService.swift`
- Modify: `DailyFlowTests/Services/InsightsServiceTests.swift`

- [ ] **Step 1: Написать 4 failing-теста**

Добавить **внутри** `struct InsightsServiceTests`, после `static func day(_:)`:

```swift
    // MARK: — tasksRate

    @Test func tasksRate_returnsNil_whenNoTasksInWindow() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        #expect(InsightsService.tasksRate(today: Self.today, in: ctx) == nil)
    }

    @Test func tasksRate_excludesTasksOutsideWindow() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // Задача за пределами окна (today − 7) — не учитывается.
        ctx.insert(DailyTask(title: "Out of window", date: Self.day(-7)))
        // Задача в окне (today) — учитывается.
        ctx.insert(DailyTask(title: "In window", date: Self.today))
        try ctx.save()
        // 1 задача в окне, не закрыта → 0.0.
        #expect(InsightsService.tasksRate(today: Self.today, in: ctx) == 0.0)
    }

    @Test func tasksRate_returnsCorrectFraction() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        for i in 0..<5 {
            let task = DailyTask(title: "T\(i)", date: Self.day(-i))
            if i < 3 {
                task.isCompleted = true
                task.completedAt = .now
            }
            ctx.insert(task)
        }
        try ctx.save()
        let rate = InsightsService.tasksRate(today: Self.today, in: ctx)
        #expect(abs((rate ?? -1) - 0.6) < 0.0001)
    }

    @Test func tasksRate_ignoresFutureTasks() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // Задача "на завтра" не входит в окно [today−6 … today].
        ctx.insert(DailyTask(title: "Tomorrow", date: Self.day(1)))
        try ctx.save()
        #expect(InsightsService.tasksRate(today: Self.today, in: ctx) == nil)
    }
```

- [ ] **Step 2: Запустить — должны падать на компиляции**

Run:
```bash
set -o pipefail && xcodebuild test \
  -project DailyFlow.xcodeproj -scheme DailyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:DailyFlowTests/InsightsServiceTests \
  | xcbeautify
```
Expected: BUILD FAILED. Сообщение «type 'InsightsService' has no member 'tasksRate'».

- [ ] **Step 3: Реализовать `tasksRate`**

Добавить в `InsightsService.swift` внутри `enum`:

```swift
    // MARK: — Окно

    /// Возвращает (start, end) окна [today−6 ... today], обе даты на startOfDay.
    private static func window(today: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: today)
        let start = cal.date(byAdding: .day, value: -6, to: end)!
        return (start, end)
    }

    // MARK: — tasksRate

    /// Доля выполненных задач за окно [today−6 ... today]. nil если задач 0.
    static func tasksRate(today: Date, in ctx: ModelContext) -> Double? {
        let (start, end) = window(today: today)
        let predicate = #Predicate<DailyTask> { $0.date >= start && $0.date <= end }
        guard let tasks = try? ctx.fetch(FetchDescriptor<DailyTask>(predicate: predicate)),
              !tasks.isEmpty else { return nil }
        let completed = tasks.lazy.filter(\.isCompleted).count
        return Double(completed) / Double(tasks.count)
    }
```

- [ ] **Step 4: Запустить тесты, убедиться что 4 проходят**

Run: тот же xcodebuild test.
Expected: `Test Suite 'InsightsService' passed`, 4 tests passed.

- [ ] **Step 5: Lint + format**

Run: `/lint` затем `/format`.
Expected: 0 warnings, 0 changes.

- [ ] **Step 6: Commit**

```bash
git add DailyFlow/Services/InsightsService.swift DailyFlowTests/Services/InsightsServiceTests.swift
git commit -m "feat(insights): InsightsService.tasksRate + 4 tests

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: `habitsRate` (5 тестов) — самая нетривиальная функция

**Files:**
- Modify: `DailyFlow/Services/InsightsService.swift`
- Modify: `DailyFlowTests/Services/InsightsServiceTests.swift`

- [ ] **Step 1: Написать 5 failing-тестов**

Добавить в `InsightsServiceTests` после блока tasksRate:

```swift
    // MARK: — habitsRate

    @Test func habitsRate_returnsNil_whenNoHabits() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        #expect(InsightsService.habitsRate(today: Self.today, in: ctx) == nil)
    }

    @Test func habitsRate_returnsNil_whenAllHabitsCreatedAfterToday() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h = Habit(name: "Future", colorHex: "2DD4A0", sortOrder: 0)
        // createdAt вручную в будущее (тестовый трюк).
        h.createdAt = Self.day(1)
        ctx.insert(h)
        try ctx.save()
        #expect(InsightsService.habitsRate(today: Self.today, in: ctx) == nil)
    }

    @Test func habitsRate_returnsOne_whenAllHabitsDoneEveryDay() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h1 = Habit(name: "H1", colorHex: "2DD4A0", sortOrder: 0)
        let h2 = Habit(name: "H2", colorHex: "F0A23B", sortOrder: 1)
        h1.createdAt = Self.day(-30)
        h2.createdAt = Self.day(-30)
        ctx.insert(h1); ctx.insert(h2)
        for offset in -6...0 {
            ctx.insert(HabitLog(date: Self.day(offset), habit: h1))
            ctx.insert(HabitLog(date: Self.day(offset), habit: h2))
        }
        try ctx.save()
        let rate = InsightsService.habitsRate(today: Self.today, in: ctx)
        #expect(abs((rate ?? -1) - 1.0) < 0.0001)
    }

    @Test func habitsRate_perDayAveraging() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h1 = Habit(name: "H1", colorHex: "2DD4A0", sortOrder: 0)
        let h2 = Habit(name: "H2", colorHex: "F0A23B", sortOrder: 1)
        h1.createdAt = Self.day(-30)
        h2.createdAt = Self.day(-30)
        ctx.insert(h1); ctx.insert(h2)
        // День -6: оба сделаны → 2/2 = 1.0
        ctx.insert(HabitLog(date: Self.day(-6), habit: h1))
        ctx.insert(HabitLog(date: Self.day(-6), habit: h2))
        // День -5: только h1 → 1/2 = 0.5
        ctx.insert(HabitLog(date: Self.day(-5), habit: h1))
        // Дни -4 ... 0: оба не сделаны → 0/2 = 0.0
        try ctx.save()
        // Среднее: (1.0 + 0.5 + 0 + 0 + 0 + 0 + 0) / 7 = 1.5 / 7 ≈ 0.2143
        let rate = InsightsService.habitsRate(today: Self.today, in: ctx)
        #expect(abs((rate ?? -1) - (1.5 / 7.0)) < 0.0001)
    }

    @Test func habitsRate_excludesDaysBeforeFirstHabit() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // Привычка создана 2 дня назад. Дни -6...-3 не имеют активных привычек → skip.
        let h = Habit(name: "Newcomer", colorHex: "2DD4A0", sortOrder: 0)
        h.createdAt = Self.day(-2)
        ctx.insert(h)
        ctx.insert(HabitLog(date: Self.day(-2), habit: h))
        ctx.insert(HabitLog(date: Self.day(-1), habit: h))
        ctx.insert(HabitLog(date: Self.day(0), habit: h))
        try ctx.save()
        // Активны 3 дня (-2, -1, 0), все сделаны → среднее [1.0, 1.0, 1.0] = 1.0.
        let rate = InsightsService.habitsRate(today: Self.today, in: ctx)
        #expect(abs((rate ?? -1) - 1.0) < 0.0001)
    }
```

- [ ] **Step 2: Запустить — fail на компиляции**

Run: тот же xcodebuild test.
Expected: BUILD FAILED — нет `habitsRate`.

- [ ] **Step 3: Реализовать `habitsRate`**

Добавить в `InsightsService` после `tasksRate`:

```swift
    // MARK: — habitsRate

    /// Среднее «дневной доли выполненных привычек» по окну.
    /// Для каждого дня окна с активными привычками (createdAt.startOfDay <= day)
    /// считаем activeLogs / activeHabits. Возвращает среднее в [0...1].
    /// nil если ни одного активного дня.
    static func habitsRate(today: Date, in ctx: ModelContext) -> Double? {
        let (start, end) = window(today: today)
        let cal = Calendar.current
        guard let habits = try? ctx.fetch(FetchDescriptor<Habit>()) else { return nil }
        if habits.isEmpty { return nil }

        // Собираем все даты окна (7 шт.) от start до end включительно.
        var dates: [Date] = []
        var cursor = start
        while cursor <= end {
            dates.append(cursor)
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }

        var dailyRates: [Double] = []
        for day in dates {
            let activeHabits = habits.filter { cal.startOfDay(for: $0.createdAt) <= day }
            if activeHabits.isEmpty { continue }
            let activeIDs = Set(activeHabits.map(\.id))
            let activeLogs = activeHabits.reduce(0) { acc, habit in
                acc + habit.logs.filter { $0.date == day && activeIDs.contains(habit.id) }.count
            }
            dailyRates.append(Double(activeLogs) / Double(activeHabits.count))
        }
        if dailyRates.isEmpty { return nil }
        return dailyRates.reduce(0, +) / Double(dailyRates.count)
    }
```

- [ ] **Step 4: Запустить — все 9 тестов (4 + 5) проходят**

Run: тот же xcodebuild test.
Expected: 9 tests passed.

- [ ] **Step 5: Lint + format**

Run: `/lint` затем `/format`.

- [ ] **Step 6: Commit**

```bash
git add DailyFlow/Services/InsightsService.swift DailyFlowTests/Services/InsightsServiceTests.swift
git commit -m "feat(insights): InsightsService.habitsRate + 5 tests

Per-day averaging formula. nil when no active days in window.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: `moodRate` (3 теста)

**Files:**
- Modify: `DailyFlow/Services/InsightsService.swift`
- Modify: `DailyFlowTests/Services/InsightsServiceTests.swift`

- [ ] **Step 1: Написать 3 failing-теста**

Добавить в `InsightsServiceTests`:

```swift
    // MARK: — moodRate

    @Test func moodRate_returnsNil_whenNoEntries() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        #expect(InsightsService.moodRate(today: Self.today, in: ctx) == nil)
    }

    @Test func moodRate_normalizesToRate() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // [5, 5, 5] → avg = 5.0 → rate = (5 − 1) / 4 = 1.0
        for i in 0..<3 {
            ctx.insert(JournalEntry(date: Self.day(-i), moodScore: 5))
        }
        try ctx.save()
        #expect(abs((InsightsService.moodRate(today: Self.today, in: ctx) ?? -1) - 1.0) < 0.0001)

        // Очистим и проверим [3] → 0.5
        for entry in (try? ctx.fetch(FetchDescriptor<JournalEntry>())) ?? [] {
            ctx.delete(entry)
        }
        try ctx.save()
        ctx.insert(JournalEntry(date: Self.today, moodScore: 3))
        try ctx.save()
        #expect(abs((InsightsService.moodRate(today: Self.today, in: ctx) ?? -1) - 0.5) < 0.0001)

        // Очистим и проверим [1, 1] → 0.0
        for entry in (try? ctx.fetch(FetchDescriptor<JournalEntry>())) ?? [] {
            ctx.delete(entry)
        }
        try ctx.save()
        ctx.insert(JournalEntry(date: Self.day(-1), moodScore: 1))
        ctx.insert(JournalEntry(date: Self.day(0), moodScore: 1))
        try ctx.save()
        #expect(abs((InsightsService.moodRate(today: Self.today, in: ctx) ?? -1) - 0.0) < 0.0001)
    }

    @Test func moodRate_excludesEntriesOutsideWindow() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        ctx.insert(JournalEntry(date: Self.day(-7), moodScore: 5))   // вне окна
        try ctx.save()
        #expect(InsightsService.moodRate(today: Self.today, in: ctx) == nil)
    }
```

- [ ] **Step 2: Запустить — fail на компиляции**

Expected: нет `moodRate`.

- [ ] **Step 3: Реализовать `moodRate`**

Добавить в сервис:

```swift
    // MARK: — moodRate

    /// Среднее настроение за окно, нормированное в [0...1].
    /// rate = (avg − 1) / 4, где avg = среднее JournalEntry.moodScore.
    /// nil если 0 записей.
    static func moodRate(today: Date, in ctx: ModelContext) -> Double? {
        let (start, end) = window(today: today)
        let predicate = #Predicate<JournalEntry> { $0.date >= start && $0.date <= end }
        guard let entries = try? ctx.fetch(FetchDescriptor<JournalEntry>(predicate: predicate)),
              !entries.isEmpty else { return nil }
        let sum = entries.reduce(0) { $0 + $1.moodScore }
        let avg = Double(sum) / Double(entries.count)
        return (avg - 1.0) / 4.0
    }
```

- [ ] **Step 4: Запустить — 12 тестов (4 + 5 + 3) проходят**

- [ ] **Step 5: Lint + format**

- [ ] **Step 6: Commit**

```bash
git add DailyFlow/Services/InsightsService.swift DailyFlowTests/Services/InsightsServiceTests.swift
git commit -m "feat(insights): InsightsService.moodRate + 3 tests

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 5: `topStreaks` (3 теста)

**Files:**
- Modify: `DailyFlow/Services/InsightsService.swift`
- Modify: `DailyFlowTests/Services/InsightsServiceTests.swift`

- [ ] **Step 1: Написать 3 failing-теста**

```swift
    // MARK: — topStreaks

    @Test func topStreaks_emptyArray_whenNoHabits() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let result = InsightsService.topStreaks(limit: 3, today: Self.today, in: ctx)
        #expect(result.isEmpty)
    }

    @Test func topStreaks_filtersOutZeroStreaks() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let h = Habit(name: "Inactive", colorHex: "2DD4A0", sortOrder: 0)
        h.createdAt = Self.day(-30)
        ctx.insert(h)
        try ctx.save()
        // Логов нет → стрик 0 → не должен попасть в результат.
        let result = InsightsService.topStreaks(limit: 3, today: Self.today, in: ctx)
        #expect(result.isEmpty)
    }

    @Test func topStreaks_sortedDescending_andLimited() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // 4 привычки со стриками 12, 7, 3, 1.
        let configs: [(name: String, streak: Int)] = [
            ("Twelve", 12), ("Seven", 7), ("Three", 3), ("One", 1),
        ]
        for (i, config) in configs.enumerated() {
            let habit = Habit(name: config.name, colorHex: "2DD4A0", sortOrder: i)
            habit.createdAt = Self.day(-30)
            ctx.insert(habit)
            for offset in 0..<config.streak {
                ctx.insert(HabitLog(date: Self.day(-offset), habit: habit))
            }
        }
        try ctx.save()
        let result = InsightsService.topStreaks(limit: 3, today: Self.today, in: ctx)
        #expect(result.count == 3)
        #expect(result[0].value == 12)
        #expect(result[1].value == 7)
        #expect(result[2].value == 3)
    }
```

- [ ] **Step 2: Запустить — fail на компиляции**

- [ ] **Step 3: Реализовать `topStreaks`**

```swift
    // MARK: — topStreaks

    /// Топ-N привычек по value текущего стрика. Сортирует по убыванию value,
    /// фильтрует value > 0. Использует HabitService.streak(for:relativeTo:).
    static func topStreaks(
        limit: Int,
        today: Date,
        in ctx: ModelContext
    ) -> [(habit: Habit, value: Int, isActive: Bool)] {
        guard let habits = try? ctx.fetch(FetchDescriptor<Habit>()) else { return [] }
        let scored = habits.map { habit -> (habit: Habit, value: Int, isActive: Bool) in
            let s = HabitService.streak(for: habit, relativeTo: today)
            return (habit: habit, value: s.value, isActive: s.isActive)
        }
        return scored
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0 }
    }
```

- [ ] **Step 4: Запустить — 15 тестов проходят**

- [ ] **Step 5: Lint + format**

- [ ] **Step 6: Commit**

```bash
git add DailyFlow/Services/InsightsService.swift DailyFlowTests/Services/InsightsServiceTests.swift
git commit -m "feat(insights): InsightsService.topStreaks + 3 tests

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6: `moodSeries` (3 теста)

**Files:**
- Modify: `DailyFlow/Services/InsightsService.swift`
- Modify: `DailyFlowTests/Services/InsightsServiceTests.swift`

- [ ] **Step 1: Написать 3 failing-теста**

```swift
    // MARK: — moodSeries

    @Test func moodSeries_returnsExactlySevenEntries() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let series = InsightsService.moodSeries(today: Self.today, in: ctx)
        #expect(series.count == 7)
        for point in series {
            #expect(point.score == nil)
        }
    }

    @Test func moodSeries_orderedFromOldestToToday() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        let series = InsightsService.moodSeries(today: Self.today, in: ctx)
        #expect(series.first?.date == Self.day(-6))
        #expect(series.last?.date == Self.day(0))
    }

    @Test func moodSeries_mapsScoresToCorrectDays() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        ctx.insert(JournalEntry(date: Self.day(-3), moodScore: 4))
        ctx.insert(JournalEntry(date: Self.day(0), moodScore: 5))
        try ctx.save()
        let series = InsightsService.moodSeries(today: Self.today, in: ctx)
        #expect(series.count == 7)
        #expect(series[3].score == 4)   // index 3 == day(-3) (0..6 = -6..0)
        #expect(series[6].score == 5)   // index 6 == today
        #expect(series[0].score == nil) // day(-6) — нет записи
    }
```

- [ ] **Step 2: Запустить — fail на компиляции**

- [ ] **Step 3: Реализовать `moodSeries`**

```swift
    // MARK: — moodSeries

    /// Ровно 7 элементов от today−6 до today. score == nil → нет записи в этот день.
    static func moodSeries(today: Date, in ctx: ModelContext)
        -> [(date: Date, score: Int?)]
    {
        let (start, end) = window(today: today)
        let cal = Calendar.current
        let predicate = #Predicate<JournalEntry> { $0.date >= start && $0.date <= end }
        let entries = (try? ctx.fetch(FetchDescriptor<JournalEntry>(predicate: predicate))) ?? []
        let byDate = Dictionary(uniqueKeysWithValues: entries.map { ($0.date, $0.moodScore) })

        var result: [(date: Date, score: Int?)] = []
        var cursor = start
        while cursor <= end {
            result.append((date: cursor, score: byDate[cursor]))
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return result
    }
```

- [ ] **Step 4: Запустить — 18 тестов проходят**

- [ ] **Step 5: Lint + format**

- [ ] **Step 6: Commit**

```bash
git add DailyFlow/Services/InsightsService.swift DailyFlowTests/Services/InsightsServiceTests.swift
git commit -m "feat(insights): InsightsService.moodSeries + 3 tests

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 7: `uniqueDataDays` (3 теста)

**Files:**
- Modify: `DailyFlow/Services/InsightsService.swift`
- Modify: `DailyFlowTests/Services/InsightsServiceTests.swift`

- [ ] **Step 1: Написать 3 failing-теста**

```swift
    // MARK: — uniqueDataDays

    @Test func uniqueDataDays_zero_whenNoData() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        #expect(InsightsService.uniqueDataDays(today: Self.today, in: ctx) == 0)
    }

    @Test func uniqueDataDays_countsAcrossAllEntities() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        // Task сегодня + Habit log вчера + Journal сегодня → 2 уникальных дня.
        let h = Habit(name: "H", colorHex: "2DD4A0", sortOrder: 0)
        ctx.insert(h)
        ctx.insert(DailyTask(title: "T", date: Self.today))
        ctx.insert(HabitLog(date: Self.day(-1), habit: h))
        ctx.insert(JournalEntry(date: Self.today, moodScore: 4))
        try ctx.save()
        #expect(InsightsService.uniqueDataDays(today: Self.today, in: ctx) == 2)
    }

    @Test func uniqueDataDays_excludesOutsideWindow() throws {
        let container = try TestContainer.make()
        let ctx = container.mainContext
        ctx.insert(DailyTask(title: "Old", date: Self.day(-7)))
        try ctx.save()
        #expect(InsightsService.uniqueDataDays(today: Self.today, in: ctx) == 0)
    }
```

- [ ] **Step 2: Запустить — fail на компиляции**

- [ ] **Step 3: Реализовать `uniqueDataDays`**

```swift
    // MARK: — uniqueDataDays

    /// Количество уникальных дней в окне с хотя бы одной записью
    /// в DailyTask, HabitLog или JournalEntry.
    static func uniqueDataDays(today: Date, in ctx: ModelContext) -> Int {
        let (start, end) = window(today: today)
        var dates = Set<Date>()

        let taskPred = #Predicate<DailyTask> { $0.date >= start && $0.date <= end }
        let logPred = #Predicate<HabitLog> { $0.date >= start && $0.date <= end }
        let entryPred = #Predicate<JournalEntry> { $0.date >= start && $0.date <= end }

        if let tasks = try? ctx.fetch(FetchDescriptor<DailyTask>(predicate: taskPred)) {
            dates.formUnion(tasks.map(\.date))
        }
        if let logs = try? ctx.fetch(FetchDescriptor<HabitLog>(predicate: logPred)) {
            dates.formUnion(logs.map(\.date))
        }
        if let entries = try? ctx.fetch(FetchDescriptor<JournalEntry>(predicate: entryPred)) {
            dates.formUnion(entries.map(\.date))
        }
        return dates.count
    }
```

- [ ] **Step 4: Запустить — все 21 тест проходит**

Run полный сьют:
```bash
set -o pipefail && xcodebuild test \
  -project DailyFlow.xcodeproj -scheme DailyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:DailyFlowTests/InsightsServiceTests \
  | xcbeautify
```
Expected: 21 tests passed.

- [ ] **Step 5: Lint + format**

- [ ] **Step 6: Commit**

```bash
git add DailyFlow/Services/InsightsService.swift DailyFlowTests/Services/InsightsServiceTests.swift
git commit -m "feat(insights): InsightsService.uniqueDataDays + 3 tests; service complete

21/21 tests passing.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 2: Дизайн-токен `dfStat`

### Task 8: Добавить модификатор `.dfStat()`

**Files:**
- Modify: `DailyFlow/Extensions/ViewExtensions.swift`

- [ ] **Step 1: Добавить модификатор**

В конец `ViewExtensions.swift` (перед закрывающей `}` extension):

```swift
    func dfStat() -> some View {
        font(.system(size: 28, weight: .semibold))
    }
```

- [ ] **Step 2: Build**

Run: `/build`
Expected: ✅ build ok.

- [ ] **Step 3: Lint + format**

- [ ] **Step 4: Commit**

```bash
git add DailyFlow/Extensions/ViewExtensions.swift
git commit -m "feat(design): add .dfStat() modifier (28pt .semibold)

SF Pro Title 2. Used for big stat numbers in MetricCardView.
Final size may be tuned in simulator (see spec §12.2).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 3: UI-компоненты

### Task 9: `MetricCardView`

**Files:**
- Create: `DailyFlow/Views/Insights/MetricCardView.swift`

- [ ] **Step 1: Создать файл целиком**

```swift
import SwiftUI

enum MetricKind {
    case tasks
    case habits
    case mood

    var caption: String {
        switch self {
        case .tasks: return "ЗАДАЧИ"
        case .habits: return "ПРИВЫЧКИ"
        case .mood: return "НАСТРОЕНИЕ"
        }
    }

    var label: String {
        switch self {
        case .tasks: return "закрыто за 7 дн."
        case .habits: return "в среднем за день"
        case .mood: return "в среднем за 7 дн."
        }
    }

    var color: Color {
        switch self {
        case .tasks: return .accentTeal
        case .habits: return .accentAmber
        case .mood: return .accentPurple
        }
    }
}

struct MetricCardView: View {
    let kind: MetricKind
    /// rate ∈ [0.0 ... 1.0]; nil → "—"
    let rate: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind.caption).dfCaption()

            Text(formattedValue)
                .dfStat()
                .foregroundStyle(rate == nil ? Color.textGhost : kind.color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            progressBar

            Text(kind.label).dfLabel()
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dfCard()
    }

    private var formattedValue: String {
        guard let rate else { return "—" }
        let percent = Int((rate * 100).rounded())
        return "\(percent)%"
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.bgPixelInactive)
                Rectangle()
                    .fill(kind.color)
                    .frame(width: max(0, geo.size.width * (rate ?? 0)))
            }
        }
        .frame(height: 3)
        .clipShape(.rect(cornerRadius: 1.5))
    }
}

#Preview {
    HStack(spacing: 12) {
        MetricCardView(kind: .tasks, rate: 0.75)
        MetricCardView(kind: .habits, rate: 0.62)
        MetricCardView(kind: .mood, rate: 0.84)
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}

#Preview("Nil values") {
    HStack(spacing: 12) {
        MetricCardView(kind: .tasks, rate: nil)
        MetricCardView(kind: .habits, rate: nil)
        MetricCardView(kind: .mood, rate: nil)
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build**

Run: `/build`
Expected: ✅ build ok.

- [ ] **Step 3: Открыть превью в Xcode** (опционально, для визуальной проверки)

Открыть `MetricCardView.swift` в Xcode, активировать Canvas (`Cmd+Option+Return`).
Проверить: 3 карточки с цифрами 75%/62%/84%, прогресс-бары соответствующие, цвета teal/amber/purple. Второе превью — три прочерка с пустыми барами.

- [ ] **Step 4: Lint + format**

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Views/Insights/MetricCardView.swift
git commit -m "feat(insights): MetricCardView with unified % format

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 10: `StreakRowView`

**Files:**
- Create: `DailyFlow/Views/Insights/StreakRowView.swift`

- [ ] **Step 1: Создать файл целиком**

```swift
import SwiftUI

struct StreakRowView: View {
    let habit: Habit
    let value: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: habit.colorHex))
                .frame(width: 8, height: 8)
            Text(habit.name).dfBody()
            Spacer()
            Text("\(value)")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? Color(hex: habit.colorHex) : Color.textGhost)
        }
        .frame(height: 36)
    }
}

#Preview {
    let habit = Habit(name: "Утренняя пробежка", colorHex: "2DD4A0", sortOrder: 0)
    return VStack(spacing: 12) {
        StreakRowView(habit: habit, value: 12, isActive: true)
        StreakRowView(habit: habit, value: 7, isActive: false)
    }
    .dfCard()
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build**

Run: `/build`. Expected: ✅ build ok.

- [ ] **Step 3: Lint + format**

- [ ] **Step 4: Commit**

```bash
git add DailyFlow/Views/Insights/StreakRowView.swift
git commit -m "feat(insights): StreakRowView (active/inactive variants)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 11: `MoodChartView`

**Files:**
- Create: `DailyFlow/Views/Insights/MoodChartView.swift`

**Зависит от:** Task 0 (research) — выбор подхода к пустым слотам.

- [ ] **Step 1: Создать файл с базовой реализацией**

```swift
import SwiftUI
import Charts

struct MoodChartView: View {
    /// Ровно 7 элементов от today−6 до today.
    let series: [(date: Date, score: Int?)]
    let today: Date

    var body: some View {
        Chart {
            // Невидимая референс-точка для каждого дня:
            // гарантирует, что ось X не схлопнется при отсутствии BarMark.
            ForEach(series, id: \.date) { point in
                RuleMark(x: .value("День", point.date, unit: .day))
                    .foregroundStyle(.clear)
                    .lineStyle(StrokeStyle(lineWidth: 0))
            }
            // Реальные бары — только для дней с данными.
            ForEach(series, id: \.date) { point in
                if let score = point.score {
                    BarMark(
                        x: .value("День", point.date, unit: .day),
                        y: .value("Настроение", score)
                    )
                    .foregroundStyle(Color.accentPurple)
                    .cornerRadius(2)
                }
            }
        }
        .chartYScale(domain: 0...5)
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

#Preview("Full week") {
    let today = Calendar.current.startOfDay(for: .now)
    let series: [(date: Date, score: Int?)] = (0..<7).map { i in
        let day = Calendar.current.date(byAdding: .day, value: i - 6, to: today)!
        return (date: day, score: [3, 4, 2, 5, 4, 3, 5][i])
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
    let series: [(date: Date, score: Int?)] = (0..<7).map { i in
        let day = Calendar.current.date(byAdding: .day, value: i - 6, to: today)!
        return (date: day, score: scores[i])
    }
    return MoodChartView(series: series, today: today)
        .dfCard()
        .padding()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
```

**Примечание:** `RuleMark` с `foregroundStyle(.clear)` и `lineWidth: 0` — это «привязка» оси X к каждой дате. Если research из Task 0 показал, что без неё ось схлопывается — этот подход решает. Если research показал, что `AxisMarks(values:)` сам справляется — `RuleMark`-блок можно убрать.

- [ ] **Step 2: Build**

Run: `/build`. Expected: ✅ build ok.

- [ ] **Step 3: Открыть превью «With gaps» и визуально проверить**

В Xcode Canvas: 7 позиций оси X (числа дней), 4 фиолетовых бара (на индексах 0, 3, 4, 6), 3 пустых слота (1, 2, 5). Все позиции равномерные, бары не сдвигаются.

**Если позиции сдвигаются** (бары прижимаются друг к другу) — переключиться на fallback HStack из 7 `Capsule()`-баров. Реализация fallback (на случай нужды) — заменить тело `body`:

```swift
HStack(spacing: 8) {
    ForEach(Array(series.enumerated()), id: \.offset) { _, point in
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                Rectangle().fill(.clear)  // занимает фиксированную высоту
                if let score = point.score {
                    Capsule()
                        .fill(Color.accentPurple)
                        .frame(height: CGFloat(score) / 5.0 * 100)
                }
            }
            .frame(height: 100)
            Text("\(Calendar.current.component(.day, from: point.date))")
                .font(.system(size: 10))
                .foregroundStyle(
                    Calendar.current.isDate(point.date, inSameDayAs: today)
                        ? Color.textPrimary : Color.textGhost
                )
        }
        .frame(maxWidth: .infinity)
    }
}
.frame(height: 120)
```

Если использован fallback — добавить заметку в `CLAUDE.md` → «Известные проблемы».

- [ ] **Step 4: Lint + format**

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Views/Insights/MoodChartView.swift
git commit -m "feat(insights): MoodChartView with empty-slot handling

Uses RuleMark anchors to keep X axis positions stable even when
some days lack JournalEntry. Fallback HStack documented in spec §12.1.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 12: `EmptyInsightsView`

**Files:**
- Create: `DailyFlow/Views/Insights/EmptyInsightsView.swift`

- [ ] **Step 1: Создать файл целиком**

```swift
import SwiftUI

struct EmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Нужно ещё немного данных")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color.textGhost)
            Text("Пользуйся приложением 3 дня,\nчтобы увидеть статистику")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

#Preview {
    EmptyInsightsView()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build + Lint + format**

- [ ] **Step 3: Commit**

```bash
git add DailyFlow/Views/Insights/EmptyInsightsView.swift
git commit -m "feat(insights): EmptyInsightsView (centered text, no illustrations)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 4: Preview-сценарий

### Task 13: Добавить `.fullWeek` в `PreviewContainer`

**Files:**
- Modify: `DailyFlow/Extensions/PreviewContainer.swift`

- [ ] **Step 1: Добавить кейс в enum**

В `enum PreviewScenario` добавить кейс `case fullWeek` в конец:

```swift
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
    // Инсайты:
    case fullWeek
}
```

- [ ] **Step 2: Добавить ветку в switch**

В `switch scenario` (внутри `static func preview(_:)`) добавить ветку перед закрывающей `}`:

```swift
        case .fullWeek:
            // 7 дней задач: ~70% выполнения.
            for i in 0..<7 {
                let day = Calendar.current.date(byAdding: .day, value: -i, to: today)!
                let count = i % 2 == 0 ? 3 : 2
                for j in 0..<count {
                    let task = DailyTask(title: "Задача \(j+1)", date: day)
                    if (i + j) % 3 != 0 {
                        task.isCompleted = true
                        task.completedAt = .now
                    }
                    ctx.insert(task)
                }
            }

            // 3 привычки старого возраста, разные стрики.
            let h1 = Habit(name: "Медитация", colorHex: "2DD4A0", sortOrder: 0)
            let h2 = Habit(name: "Спорт", colorHex: "F0A23B", sortOrder: 1)
            let h3 = Habit(name: "Чтение", colorHex: "9B8AE8", sortOrder: 2)
            for habit in [h1, h2, h3] {
                habit.createdAt = Calendar.current.date(byAdding: .day, value: -30, to: today)!
                ctx.insert(habit)
            }
            // h1: стрик 7
            for i in 0..<7 {
                let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
                ctx.insert(HabitLog(date: date, habit: h1))
            }
            // h2: стрик 3 (включая сегодня)
            for i in 0..<3 {
                let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
                ctx.insert(HabitLog(date: date, habit: h2))
            }
            // h3: стрик 1
            ctx.insert(HabitLog(date: today, habit: h3))

            // 5 записей в дневник со score 3..5
            let scores = [3, 4, 5, 4, 5]
            for (i, score) in scores.enumerated() {
                let day = Calendar.current.date(byAdding: .day, value: -i, to: today)!
                ctx.insert(JournalEntry(date: day, moodScore: score))
            }
```

- [ ] **Step 3: Build**

Run: `/build`. Expected: ✅ build ok.

- [ ] **Step 4: Lint + format**

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Extensions/PreviewContainer.swift
git commit -m "feat(preview): add .fullWeek scenario for Insights screen

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 5: Корневые View

### Task 14: `InsightsContentView`

**Files:**
- Create: `DailyFlow/Views/Insights/InsightsContentView.swift`

- [ ] **Step 1: Создать файл целиком**

```swift
import SwiftUI
import SwiftData

struct InsightsContentView: View {
    let today: Date

    @Environment(\.modelContext) private var ctx
    // @Query без предикатов — только для реактивного триггера перерендера.
    // Фильтрация и расчёты — в InsightsService через ctx.fetch.
    @Query private var allTasks: [DailyTask]
    @Query private var allHabits: [Habit]
    @Query private var allEntries: [JournalEntry]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Инсайты")
                    .dfTitle()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if uniqueDataDays < 3 {
                    EmptyInsightsView()
                        .frame(minHeight: 400)
                } else {
                    metricsRow
                    streaksSection
                    moodSection
                }
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }

    // MARK: — Reactivity bridge

    /// Ссылка на массивы @Query внутри computed-properties — чтобы SwiftUI
    /// перерисовал View при изменении данных. Сами массивы не используются.
    private var dataChangeToken: Int {
        allTasks.count &+ allHabits.count &+ allEntries.count
    }

    // MARK: — Метрики

    private var uniqueDataDays: Int {
        _ = dataChangeToken
        return InsightsService.uniqueDataDays(today: today, in: ctx)
    }

    private var tasksRate: Double? {
        _ = dataChangeToken
        return InsightsService.tasksRate(today: today, in: ctx)
    }

    private var habitsRate: Double? {
        _ = dataChangeToken
        return InsightsService.habitsRate(today: today, in: ctx)
    }

    private var moodRate: Double? {
        _ = dataChangeToken
        return InsightsService.moodRate(today: today, in: ctx)
    }

    private var topStreaks: [(habit: Habit, value: Int, isActive: Bool)] {
        _ = dataChangeToken
        return InsightsService.topStreaks(limit: 3, today: today, in: ctx)
    }

    private var moodSeries: [(date: Date, score: Int?)] {
        _ = dataChangeToken
        return InsightsService.moodSeries(today: today, in: ctx)
    }

    // MARK: — Секции

    private var metricsRow: some View {
        HStack(spacing: 12) {
            MetricCardView(kind: .tasks, rate: tasksRate)
            MetricCardView(kind: .habits, rate: habitsRate)
            MetricCardView(kind: .mood, rate: moodRate)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var streaksSection: some View {
        let streaks = topStreaks
        if !streaks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("ЛУЧШИЕ СТРИКИ").dfCaption()
                    .padding(.horizontal, 16)
                VStack(spacing: 12) {
                    ForEach(streaks, id: \.habit.id) { item in
                        StreakRowView(habit: item.habit, value: item.value, isActive: item.isActive)
                    }
                }
                .dfCard()
                .padding(.horizontal, 16)
            }
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("НАСТРОЕНИЕ — ПОСЛЕДНИЕ 7 ДНЕЙ").dfCaption()
                .padding(.horizontal, 16)
            MoodChartView(series: moodSeries, today: today)
                .dfCard()
                .padding(.horizontal, 16)
        }
    }
}

#Preview("Empty") {
    InsightsContentView(today: Calendar.current.startOfDay(for: .now))
        .modelContainer(.preview(.empty))
        .preferredColorScheme(.dark)
}

#Preview("Full week") {
    InsightsContentView(today: Calendar.current.startOfDay(for: .now))
        .modelContainer(.preview(.fullWeek))
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build**

Run: `/build`. Expected: ✅ build ok.

- [ ] **Step 3: Открыть оба превью в Xcode Canvas**

- **Empty**: заголовок «Инсайты» + текст по центру «Нужно ещё немного данных».
- **Full week**: заголовок + 3 карточки в ряд с цветными процентами + секция «ЛУЧШИЕ СТРИКИ» с 3 строками + гистограмма.

Если что-то выглядит не так (например, заголовок прижат к safe area или прогресс-бары непропорциональны) — проверить отступы по спеке §6.1.

- [ ] **Step 4: Lint + format**

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Views/Insights/InsightsContentView.swift
git commit -m "feat(insights): InsightsContentView with empty state and 3 sections

@Query без предикатов как реактивный триггер; расчёты — в InsightsService.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 15: `InsightsView` (обёртка)

**Files:**
- Create: `DailyFlow/Views/Insights/InsightsView.swift` (заменяет существующий stub)

- [ ] **Step 1: Перезаписать файл**

```swift
import SwiftUI

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
```

- [ ] **Step 2: Build**

Run: `/build`. Expected: ✅ build ok.

- [ ] **Step 3: Lint + format**

- [ ] **Step 4: Commit**

```bash
git add DailyFlow/Views/Insights/InsightsView.swift
git commit -m "feat(insights): InsightsView wrapper with cross-midnight refresh

Двухслойная View, дублирует pattern TodayView.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 6: Удаление старых stub-файлов

### Task 16: Удалить пустой `WeekStatView.swift`

**Files:**
- Delete: `DailyFlow/Views/Insights/WeekStatView.swift`

В первоначальном промте упоминался `WeekStatView`, но в утверждённом дизайне он замещён `MetricCardView`. Стаб с `// TODO: implement` нужно убрать — иначе синхронизированный таргет компилирует пустой файл и линтер на него ругается.

- [ ] **Step 1: Удалить файл**

```bash
rm DailyFlow/Views/Insights/WeekStatView.swift
```

- [ ] **Step 2: Build**

Run: `/build`. Expected: ✅ build ok.

- [ ] **Step 3: Commit**

```bash
git add -A DailyFlow/Views/Insights/WeekStatView.swift
git commit -m "chore(insights): remove WeekStatView stub (replaced by MetricCardView)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 7: Интеграция в TabView

### Task 17: Подключить `InsightsView` в `ContentView`

**Files:**
- Modify: `DailyFlow/App/ContentView.swift`

- [ ] **Step 1: Заменить placeholder под вкладкой «Инсайты»**

Найти в `ContentView.body`:

```swift
            placeholder
                .tabItem { Label("Инсайты", systemImage: "chart.bar") }
```

Заменить на:

```swift
            InsightsView()
                .tabItem { Label("Инсайты", systemImage: "chart.bar") }
```

Placeholder для вкладки «Дневник» оставить — этот экран ещё не реализован.

- [ ] **Step 2: Build**

Run: `/build`. Expected: ✅ build ok.

- [ ] **Step 3: Lint + format**

- [ ] **Step 4: Commit**

```bash
git add DailyFlow/App/ContentView.swift
git commit -m "feat(app): wire InsightsView into TabView

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 8: Верификация

### Task 18: Полная проверка через `verification-before-completion`

**Files:** none (проверка)

- [ ] **Step 1: Полный билд**

Run: `/build`
Expected: `✅ build ok`, 0 warnings.

- [ ] **Step 2: Lint всего проекта**

Run: `/lint`
Expected: 0 warnings.

- [ ] **Step 3: Format-проверка**

Run: `/format`
Expected: 0 файлов изменено.

- [ ] **Step 4: Полный прогон тестов**

```bash
set -o pipefail && xcodebuild test \
  -project DailyFlow.xcodeproj -scheme DailyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  | xcbeautify
```
Expected: все тесты пройдены, включая `InsightsServiceTests` (21 теста), `TaskServiceTests` (14), `HabitServiceTests` (15), `DailyTaskTests` (3). Итого: 53 теста.

- [ ] **Step 5: Запуск симулятора и ручная проверка**

Run: `/sim` чтобы поднять симулятор iPhone 16 Pro и установить приложение.

Чек-лист в симуляторе:
- [ ] Открыть вкладку «Инсайты». На пустой БД (первый запуск) — empty state «Нужно ещё немного данных».
- [ ] Закрыть приложение.
- [ ] Открыть вкладку «Сегодня», добавить 3 задачи на сегодня и закрыть 2.
- [ ] Открыть «Привычки», создать 2 привычки, отметить одну сегодня.
- [ ] Перейти на «Инсайты»: должен показываться empty state, потому что в окне 1 уникальный день (today). 
   **NOTE:** в реальной жизни 1 день — это 33% порога. Чтобы увидеть полный экран — добавить тестовые данные в 3 разных дня (через миграцию/изменение даты симулятора).
- [ ] Если в проекте уже накопилось ≥3 дней данных — проверить, что:
  - Заголовок «Инсайты» виден.
  - 3 карточки в ряд показывают проценты или прочерки.
  - Прогресс-бары пропорциональны.
  - Секция «ЛУЧШИЕ СТРИКИ» показывает топ-3 (или скрыта).
  - Гистограмма показывает 7 позиций оси X с барами для дней с записью.
  - Закрытие задачи на «Сегодня» сразу меняет цифру в `% задач` на «Инсайтах» (через `@Query`).

- [ ] **Step 6: Скриншот превью обоих состояний**

Сделать `/sim`-скриншот:
- Empty state.
- Полный экран (с тестовыми данными).

Положить в комментарий PR (если будет PR) или просто оставить локально.

---

### Task 19: Обновить `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Обновить раздел «Статус»**

Найти блок «Статус» и заменить на:

```markdown
- **Статус:** 🟢 Phase 1 завершена. Phase 2 завершена. Phase 3 завершена. Экраны «Сегодня», «Привычки», «Инсайты» полностью реализованы. Build succeeded 0 warnings, 53 теста проходят. Следующий шаг — экран «Дневник» (нужен спек).
```

- [ ] **Step 2: Обновить раздел «Структура файлов»**

В дереве `DailyFlow/Views/Insights/` заменить:

```
      Insights/                         # экран «Инсайты» (отдельный спек)
```

на:

```
      Insights/
        InsightsView.swift              # обёртка scenePhase + dateAnchor
        InsightsContentView.swift       # ScrollView + 3 секции + empty state
        MetricCardView.swift            # 1 из 3 метрик (число + бар + лейбл)
        StreakRowView.swift             # строка топ-стрика
        MoodChartView.swift             # гистограмма Swift Charts
        EmptyInsightsView.swift         # текст по центру при <3 дней данных
```

В `Services/` добавить строку под `HabitService.swift`:

```
      InsightsService.swift             # бизнес-логика инсайтов (enum-namespace, stateless)
```

- [ ] **Step 3: Обновить раздел «Дизайн-система → Типографика»**

Заменить таблицу:

```markdown
| Роль | Размер | Вес | Доп. |
|---|---|---|---|
| Title | 21pt | `.medium` | — |
| Body | 13pt | `.regular` | — |
| Caption | 10pt | `.regular` | letter-spacing 0.5pt, ALL CAPS |
| **Stat** | **28pt** | **`.semibold`** | для KPI-цифр на инсайтах (`.dfStat()`) |
```

- [ ] **Step 4: Обновить раздел «Выполненные фичи»**

Поставить чек у строки «Экран Инсайты»:

```markdown
- [x] Экран «Инсайты» — полностью реализован, build ok, lint clean, 21 тест InsightsService
- [ ] Экран «Дневник» (нужен спек)
```

- [ ] **Step 5: Если использован fallback HStack в `MoodChartView`** (см. Task 11 Step 3) — добавить в раздел «Известные проблемы»:

```markdown
- **MoodChartView:** на iOS 26 использован fallback HStack из 7 Capsule()-баров вместо Swift Charts BarMark, потому что чарт схлопывал ось X при пустых слотах. Если выйдет апдейт Charts с поддержкой stable axis values — заменить обратно.
```

Если использован основной подход (Swift Charts с `RuleMark`-якорями) — этот шаг пропустить.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md after Insights implementation

- Status: Phase 3 done (Today, Habits, Insights)
- Structure: list Insights files
- Typography: add Stat token (28pt .semibold)
- Features: check Insights row

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Done

После Task 19 все acceptance-критерии спека выполнены:

- ✅ Build succeeded, 0 warnings
- ✅ Lint clean, format clean
- ✅ 21 тест `InsightsServiceTests` проходит
- ✅ Empty state на старте, реактивно снимается на 3 уникальных днях данных
- ✅ 3 метрики в едином формате %
- ✅ Топ-3 стрики (секция скрыта при пустом списке)
- ✅ Гистограмма с пустыми слотами
- ✅ Cross-midnight через `.id(dateAnchor)`
- ✅ Все View ≤ 150 строк, в каждом `#Preview`
- ✅ CLAUDE.md обновлён

Финальный шаг (опционально, для пользователя) — проверка спеком через `superpowers:requesting-code-review`.
