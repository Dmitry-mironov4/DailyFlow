# Спецификация: Экран «Сегодня» (DailyFlow)

**Дата:** 2026-05-07
**Статус:** утверждён, готов к написанию плана реализации
**Платформа:** iOS 26+, Swift 6, SwiftUI + SwiftData
**Связанные документы:** `DailyFlow/CLAUDE.md`

---

## 1. Цель экрана

Первый из четырёх экранов TabView. Совмещает:
- Просмотр задач на текущий день.
- Отображение «фокус-задачи» дня в выделенной карточке.
- Быстрое добавление новых задач (квик-капчер).
- Перенос или сброс незавершённых задач с прошлых дней (rollover-банер).

Экран задаёт **архитектурный паттерн** для остальных трёх (Привычки, Дневник, Инсайты): Pure SwiftUI + `@Query` + Service-namespace, без отдельного слоя ViewModel.

---

## 2. Журнал решений (Q1–Q5)

| № | Вопрос | Решение |
|---|---|---|
| Q1 | Как моделировать «фокус-задачу»? | `Bool isFocus` на `DailyTask`. Инвариант «один фокус в день» обеспечивается `TaskService.setFocus`. |
| Q2 | Что происходит на границе дня? | Жёсткий cutoff + банер ручного переноса. Фокус сбрасывается каждый день. |
| Q3 | Сортировка и поведение выполненных | Сортировка `createdAt ASC`. Выполненные остаются на месте, dimmed (`text.secondary` + strikethrough + opacity ~0.5). Никакого drag-to-reorder. |
| Q4 | UX добавления задачи | Inline TextField на месте ghost-кнопки. После Submit поле очищается, клавиатура остаётся. Фокус — только через `.contextMenu`. |
| Q5 | Свайпы и контекст-меню | `.contextMenu` (3 пункта: Сделать/Снять фокус, Изменить, Удалить) + trailing full-swipe «Удалить». Без leading swipe. |
| A | Архитектурный подход | **Pure SwiftUI + `@Query` + Service-struct**. Никакого `@Observable ViewModel`. UI-only state — в `@State`. |

---

## 3. Модель данных

### 3.1. `DailyTask` (`@Model`)

```swift
@Model
final class DailyTask {
    var id: UUID
    var title: String
    var isFocus: Bool         // инвариант: max 1 true на одну date
    var isCompleted: Bool     // ПРИМЕЧАНИЕ: переименовано из isDone
    var date: Date            // ВСЕГДА startOfDay (Calendar.current)
    var createdAt: Date       // для сортировки
    var completedAt: Date?    // для статистики и markdown-экспорта

    init(title: String, date: Date, isFocus: Bool = false) {
        self.id = UUID()
        self.title = title
        self.isFocus = isFocus
        self.isCompleted = false
        self.date = Calendar.current.startOfDay(for: date)
        self.createdAt = .now
        self.completedAt = nil
    }
}
```

### 3.2. Изменения относительно начального CLAUDE.md

| Поле | Было | Стало | Причина |
|---|---|---|---|
| `isDone` | `Bool` | `isCompleted: Bool` | Стандартное Swift-именование, парность с `completedAt`. |
| `completedAt` | — | `Date?` | Для статистики «когда закрыл» и markdown-экспорта. |
| `sortOrder` | `Int` (предполагался) | удалён | Сортировка по `createdAt ASC`, ручной reorder отвергнут. |

CLAUDE.md обновляется синхронно после утверждения этого спека.

---

## 4. Сервисный слой: `TaskService`

`enum`-namespace со статическими функциями. Принимает `ModelContext` явным параметром. Stateless.

### 4.1. API

```swift
enum TaskService {
    /// Возвращает nil если title после trim пустой.
    @discardableResult
    static func add(title: String,
                    isFocus: Bool = false,
                    on date: Date,
                    in ctx: ModelContext) -> DailyTask?

    static func toggleCompletion(_ task: DailyTask, in ctx: ModelContext)

    /// Атомарно: снимает isFocus у всех задач этого дня, ставит true у переданной.
    static func setFocus(_ task: DailyTask, in ctx: ModelContext) throws

    /// Снимает isFocus у всех задач указанного дня.
    static func clearFocus(on date: Date, in ctx: ModelContext) throws

    static func delete(_ task: DailyTask, in ctx: ModelContext)

    /// Игнорирует пустой title (откат к старому значению).
    static func updateTitle(_ task: DailyTask,
                            to title: String,
                            in ctx: ModelContext)

    /// Переносит все isCompleted == false с дат < target на target.
    /// При переносе: date = target, isFocus = false (вчерашний фокус не наследуется).
    /// Возвращает количество перенесённых.
    @discardableResult
    static func rolloverPending(into target: Date,
                                in ctx: ModelContext) throws -> Int

    /// Удаляет все isCompleted == false с дат < date.
    @discardableResult
    static func discardPending(before date: Date,
                               in ctx: ModelContext) throws -> Int
}
```

### 4.2. Инварианты

1. Все `date` нормализуются через `Calendar.current.startOfDay(for:)` на входе.
2. `setFocus` — атомарная операция (один проход снимает старые, ставит новый).
3. `toggleCompletion`: при `isCompleted = true` записывает `completedAt = .now`; при `false` — `completedAt = nil`.
4. `add` с `trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true` возвращает `nil` без побочных эффектов.
5. `rolloverPending` гарантирует сброс `isFocus` у переносимых задач.
6. Все методы выполняются на main actor (`ModelContext` main-bound).

---

## 5. Файловая иерархия экрана

```
DailyFlow/Views/Today/
  TodayView.swift            ≤ 60 строк    обёртка: ScenePhase + dateAnchor
  TodayContentView.swift     ≤ 130 строк   реальный UI с @Query
  FocusCardView.swift        ≤ 80 строк    accent card, edit inline
  TaskRowView.swift          ≤ 130 строк   строка списка
  AddTaskBarView.swift       ≤ 100 строк   ghost → TextField
  RolloverBannerView.swift   ≤ 70 строк    плашка переноса

DailyFlow/Models/
  DailyTask.swift            ≤ 50 строк

DailyFlow/Services/
  TaskService.swift          ≤ 150 строк   ← НОВЫЙ файл (не было в CLAUDE.md)

DailyFlow/Extensions/
  Haptics.swift              ≤ 40 строк    ← НОВЫЙ helper (UIImpactFeedbackGenerator)
  Date+StartOfDay.swift      ≤ 20 строк    ← НОВЫЙ helper

DailyFlowTests/
  Services/
    TaskServiceTests.swift   ~120 строк
  Models/
    DailyTaskTests.swift     ~40 строк
  Helpers/
    InMemoryContainer.swift  ~25 строк
```

**Изменения относительно структуры в CLAUDE.md:**
- Добавлены: `TodayContentView`, `AddTaskBarView`, `RolloverBannerView` (внутри `Views/Today/`).
- Добавлен новый сервис: `Services/TaskService.swift`.
- Добавлены вспомогательные расширения: `Extensions/Haptics.swift`, `Extensions/Date+StartOfDay.swift`.
- Создан таргет тестов `DailyFlowTests/`.

CLAUDE.md обновится синхронно.

---

## 6. Управление состоянием

### 6.1. Двухслойный `TodayView`

Решает проблему пересечения полуночи: если приложение открыто в момент смены дня, контент должен переинициализироваться с новой датой.

```swift
// TodayView.swift — обёртка
struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dateAnchor = Calendar.current.startOfDay(for: .now)

    var body: some View {
        TodayContentView(dateAnchor: dateAnchor)
            .id(dateAnchor)                          // форсит re-init при смене даты
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                let now = Calendar.current.startOfDay(for: .now)
                if now != dateAnchor { dateAnchor = now }
            }
    }
}
```

### 6.2. `TodayContentView` — `@Query` с локальным захватом даты

**Критично:** SwiftData `#Predicate` не поддерживает статические свойства типа `Self.todayStart`. Дату необходимо захватить в локальную переменную в `init`.

```swift
struct TodayContentView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var todayTasks: [DailyTask]
    @Query private var pendingFromPast: [DailyTask]

    @State private var addBarText = ""
    @State private var editingTaskId: UUID?

    private let dateAnchor: Date

    init(dateAnchor: Date) {
        self.dateAnchor = dateAnchor
        let today = dateAnchor                       // ← локальный захват, обязателен
        _todayTasks = Query(
            filter: #Predicate<DailyTask> { $0.date == today },
            sort: [SortDescriptor(\.createdAt, order: .forward)]
        )
        _pendingFromPast = Query(
            filter: #Predicate<DailyTask> {
                $0.date < today && $0.isCompleted == false
            }
        )
    }
}
```

### 6.3. Производные значения (вычисляются в `body`)

```swift
private var focus: DailyTask?      { todayTasks.first { $0.isFocus } }
private var regular: [DailyTask]   { todayTasks.filter { !$0.isFocus } }
private var completedCount: Int    { todayTasks.filter(\.isCompleted).count }
private var totalCount: Int        { todayTasks.count }
```

---

## 7. Структура body (`TodayContentView`)

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 12) {
        Header()                                     // дата (caption) + "Сегодня" (title)

        if !pendingFromPast.isEmpty {
            RolloverBannerView(
                count: pendingFromPast.count,
                onMove:    { try? TaskService.rolloverPending(into: dateAnchor, in: ctx) },
                onDiscard: { try? TaskService.discardPending(before: dateAnchor, in: ctx) }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }

        if let focus {
            FocusCardView(
                task: focus,
                isEditing: editingTaskId == focus.id,
                onToggle:     { TaskService.toggleCompletion(focus, in: ctx) },
                onStartEdit:  { editingTaskId = focus.id },
                onFinishEdit: { commitEdit(focus, $0) },
                onClearFocus: { try? TaskService.clearFocus(on: dateAnchor, in: ctx) },
                onDelete:     { TaskService.delete(focus, in: ctx) }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }

        Text("ЗАДАЧИ — \(completedCount)/\(totalCount)").dfCaption()

        LazyVStack(spacing: 0) {
            ForEach(regular) { task in
                TaskRowView(
                    task: task,
                    isEditing: editingTaskId == task.id,
                    onToggle:     { TaskService.toggleCompletion(task, in: ctx) },
                    onStartEdit:  { editingTaskId = task.id },
                    onFinishEdit: { commitEdit(task, $0) },
                    onSetFocus:   { try? TaskService.setFocus(task, in: ctx) },
                    onDelete:     { TaskService.delete(task, in: ctx) }
                )
            }
        }

        AddTaskBarView(
            text: $addBarText,
            onSubmit: { TaskService.add(title: $0, on: dateAnchor, in: ctx) }
        )
    }
    .padding(.horizontal, 16)
    .animation(.spring(duration: 0.35, bounce: 0.15), value: focus?.id)
}
.background(Color.bgPrimary)
.scrollDismissesKeyboard(.interactively)
```

### 7.1. Helper `commitEdit`

```swift
private func commitEdit(_ task: DailyTask, _ newTitle: String) {
    let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty, trimmed != task.title {
        TaskService.updateTitle(task, to: trimmed, in: ctx)
        Haptics.tap(.light)
    }
    editingTaskId = nil
}
```

---

## 8. Спецификации компонентов

### 8.1. `Header` (внутри `TodayContentView`, не отдельный файл)

- Caption: текущая дата в формате `"ЧЕТВЕРГ, 7 МАЯ"` — через `DateFormatter` ru_RU + `.uppercased()` + letter-spacing 0.5pt.
- Title: `"Сегодня"` — `.dfTitle()` (21pt `.medium`).
- Отступ снизу: 14pt.

### 8.2. `FocusCardView`

- Стиль карточки: `.dfAccentCard(color: .accentTeal)` — фон `accentTeal.opacity(0.08)`, левый бордер 3pt teal, cornerRadius 12, padding 16/14.
- Caption-лейбл: `"ФОКУС"` цветом `.accentTeal`.
- Текст задачи: 13pt `.regular`, цвет `text.primary`.
- Чекбокс справа: тот же 15pt круг, что в `TaskRowView`.
- При `isEditing`: вместо `Text(title)` рендерится `TextField` с `@FocusState`, `.onSubmit` → `onFinishEdit`.
- `.contextMenu`: «Снять с фокуса» / «Изменить» / «Удалить».
- При удалении/снятии фокуса — `.transition(.opacity.combined(with: .move(edge: .top)))`.

### 8.3. `TaskRowView`

- Высота строки: ~40pt (auto, padding `.vertical 10`).
- Слева: круг 15pt:
  - не выполнено — обводка 1.5pt `#333333`,
  - выполнено — заливка `.accentTeal` + белая галочка SF Symbol `checkmark`.
- Текст:
  - не выполнено — 13pt `.regular`, `text.primary`,
  - выполнено — цвет `.textSecondary`, strikethrough, `opacity(0.5)`,
  - `.lineLimit(2)`.
- При `isEditing`: `Text` заменяется `TextField` с автофокусом.
- Тап по чекбоксу (hit area минимум 44×44): `onToggle` + `Haptics.tap(.medium)`.
- Тап по телу строки: **ничего**.
- `.contextMenu`:
  - «Сделать фокусом» / «Снять с фокуса» (динамический заголовок) → `onSetFocus`,
  - «Изменить» → `onStartEdit`,
  - «Удалить» (`.destructive`) → `onDelete` + `Haptics.tap(.heavy)`.
- `.swipeActions(edge: .trailing, allowsFullSwipe: true)`:
  - «Удалить» (`.destructive`, иконка `trash`) → `onDelete` + `Haptics.tap(.heavy)`.

### 8.4. `AddTaskBarView`

```swift
struct AddTaskBarView: View {
    @Binding var text: String
    let onSubmit: (String) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: focused ? "circle.fill" : "plus")
                .foregroundStyle(Color.accentTeal)
                .frame(width: 16, height: 16)
                .animation(.easeInOut(duration: 0.2), value: focused)

            TextField(focused ? "Новая задача…" : "Добавить задачу", text: $text)
                .focused($focused)
                .submitLabel(.return)
                .onSubmit(submit)
                .foregroundStyle(focused ? Color.textPrimary : Color.textGhost)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if focused {
                Rectangle().fill(Color.accentTeal).frame(height: 1)
            }
        }
        .contentShape(.rect)
        .onTapGesture { focused = true }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Haptics.tap(.light)
        onSubmit(trimmed)
        text = ""        // готов к следующей; focused остаётся true
    }
}
```

### 8.5. `RolloverBannerView`

- Стиль: `.dfCard()` (фон `bg.card`, cornerRadius 12, padding 16/14).
- Левая часть: `"Незавершённых: \(count)"` — 13pt `.regular`, цвет `text.secondary`.
- Правая часть: две ghost-кнопки на одной горизонтали:
  - «Перенести» — текст цветом `.accentTeal`.
  - «Очистить» — текст цветом `text.secondary`.
- `Spacer` между текстом и кнопками.
- Хаптика на кнопках: `.light` (Перенести), `.medium` (Очистить).

---

## 9. Взаимодействия — сводная таблица

| Элемент | Жест | Действие | Хаптика |
|---|---|---|---|
| Чекбокс задачи | tap | `toggleCompletion` | `.medium` |
| Тело строки | tap | — (ничего) | — |
| Строка задачи | long-press → меню | `.contextMenu`: setFocus / edit / delete | по выбору пункта |
| Строка задачи | trailing swipe (full) | `delete` | `.heavy` |
| `FocusCardView` | long-press → меню | clearFocus / edit / delete | по выбору |
| AddBar (ghost) | tap | фокус → клавиатура | — |
| AddBar (TextField) | Return | submit + очистка | `.light` |
| AddBar | scroll | `.scrollDismissesKeyboard(.interactively)` | — |
| RolloverBanner | tap «Перенести» | `rolloverPending` | `.light` |
| RolloverBanner | tap «Очистить» | `discardPending` | `.medium` |
| Меню → «Изменить» | tap | переключение в edit-режим | — |
| Меню → «Сделать фокусом» | tap | `setFocus` | `.medium` |
| Меню → «Удалить» | tap | `delete` | `.heavy` |
| Меню → «Снять с фокуса» | tap | `clearFocus(on:)` | `.medium` |
| Edit TextField | Return | commitEdit | `.light` |

---

## 10. Анимации

| Что | Trigger | Animation | Длительность |
|---|---|---|---|
| Toggle чекбокса (галочка + strikethrough + opacity) | `task.isCompleted` | `.easeInOut` | 150ms |
| AddBar collapse/expand | `focused` | `.easeInOut` | 200ms |
| Edit-режим: Text ↔ TextField | `editingTaskId` | `.easeInOut` | 150ms |
| Появление/скрытие FocusCard | `focus?.id` | `.transition(.opacity + .move(.top))` + `.spring(duration: 0.35, bounce: 0.15)` | ~350ms |
| Появление/скрытие RolloverBanner | `pendingFromPast.isEmpty` | `.transition(.opacity + .move(.top))` | spring default |
| Удаление задачи | LazyVStack remove | стандартная | spring default |

**Запрещено:** scale-bounce, rotation, blur, parallax.

---

## 11. Хаптики (helper `Haptics`)

```swift
// Extensions/Haptics.swift
enum Haptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
```

Использование: `Haptics.tap(.medium)`. Извлечено в helper, чтобы не плодить генераторы по сайту.

---

## 12. Edge cases

| Сценарий | Ожидаемое поведение |
|---|---|
| Приложение открыто во время полуночи | `scenePhase == .active` → `dateAnchor` пересчитывается → `.id(dateAnchor)` re-init контента → `@Query` использует новую дату. |
| Пустой ввод в add-баре, Return | Игнор. Без подсветки, без тряски. |
| Edit-режим, стёрли весь текст и Return | `commitEdit` видит пустой trimmed → откат, `editingTaskId = nil`. |
| Edit-режим, приложение в фон | `scenePhase == .background` → `commitEdit(currentTask, currentBuffer)` (с откатом если пусто). |
| `setFocus` на уже-фокусной задаче | В меню отображается «Снять с фокуса» → `clearFocus(on: dateAnchor)`. |
| `setFocus` на выполненной задаче | Разрешено. FocusCard рисует чекбокс отмеченным. |
| Двойной тап «Сделать фокусом» | Идемпотентно: проход по `tasks where date == X && isFocus == true` снимает у всех, ставит у текущей. Race невозможен — main actor. |
| Trailing swipe во время edit | Свайп закрывает edit без сохранения (`.destructive` action отменяет фокус) → задача удаляется. Это ожидаемое поведение пользователя, который сам свайпнул. |
| Удаление фокус-задачи | FocusCard анимированно сворачивается. Следующая задача автоматически НЕ становится фокусом. |
| Длинный заголовок (>200 символов) | Без хард-лимита. `TaskRowView` — `.lineLimit(2)`. Edit-режим — полный TextField. |
| Rollover двойной тап «Перенести» | После первого `pendingFromPast.isEmpty == true` → банер уходит → второй тап невозможен. |
| `pendingFromPast` несколько дней назад | Текст «Незавершённых: X» собирает все дни. Перенос ставит `date = dateAnchor` и `isFocus = false` всем. |

---

## 13. Empty states

| Состояние | Что показывать |
|---|---|
| Нет задач сегодня, нет накопленных | Header + AddBar. Никаких empty-state иллюстраций. AddBar = зов к действию. |
| Есть задачи, фокус не выбран | Header → лейбл `ЗАДАЧИ — X/Y` → список → AddBar. Без FocusCard. |
| Все задачи выполнены | Лейбл `Y/Y`. Никаких эмоциональных сообщений. |

---

## 14. Тестирование

### 14.1. Стек

**Swift Testing** (нативный для iOS 26+ / Swift 6). Не XCTest.

### 14.2. Файлы

```
DailyFlowTests/
  Services/TaskServiceTests.swift
  Models/DailyTaskTests.swift
  Helpers/InMemoryContainer.swift
```

### 14.3. `InMemoryContainer.swift`

```swift
@MainActor
enum TestContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            DailyTask.self,
            Habit.self,
            HabitLog.self,
            JournalEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

### 14.4. Минимальный набор `TaskServiceTests`

```swift
@Suite("TaskService") @MainActor
struct TaskServiceTests {
    @Test func add_returnsNilForEmptyTitle() throws { /* ... */ }
    @Test func add_trimsWhitespace() throws { /* ... */ }
    @Test func toggleCompletion_setsCompletedAt() throws { /* ... */ }
    @Test func toggleCompletion_unsetsCompletedAt_whenUntoggled() throws { /* ... */ }
    @Test func setFocus_clearsPreviousFocusOnSameDay() throws { /* ... */ }
    @Test func setFocus_doesNotAffectOtherDays() throws { /* ... */ }
    @Test func clearFocus_removesAllFocusFlagsOnDay() throws { /* ... */ }
    @Test func updateTitle_ignoresEmpty() throws { /* ... */ }
    @Test func rolloverPending_movesIncompleteFromPastDays() throws { /* ... */ }
    @Test func rolloverPending_preservesTitle_dropsFocusFlag() throws { /* ... */ }
    @Test func rolloverPending_skipsCompletedTasks() throws { /* ... */ }
    @Test func discardPending_deletesOnlyPastIncomplete() throws { /* ... */ }
}
```

### 14.5. Что НЕ тестируется

- SwiftUI рендер (UI testing — overkill для personal app).
- `@Query` реактивность — это контракт фреймворка.
- Хаптики — нет публичного API.
- Анимации.

### 14.6. Превью как «визуальные тесты»

```swift
#Preview("Empty")          { TodayContentView(dateAnchor: .now).modelContainer(.preview(.empty)) }
#Preview("Only focus")     { TodayContentView(dateAnchor: .now).modelContainer(.preview(.onlyFocus)) }
#Preview("Mixed")          { TodayContentView(dateAnchor: .now).modelContainer(.preview(.mixed)) }
#Preview("With banner")    { TodayContentView(dateAnchor: .now).modelContainer(.preview(.withRollover)) }
#Preview("Edit mode")      { TodayContentView(dateAnchor: .now).modelContainer(.preview(.editingFirst)) }
```

`ModelContainer.preview(_:)` — расширение в `Extensions/PreviewContainer.swift`, создаёт in-memory контейнер с заранее заготовленными сценариями. Этот файл — НОВЫЙ, не было в CLAUDE.md, добавляется.

---

## 15. Out of scope (явный YAGNI)

Не делать в v1:

- Drag-to-reorder задач.
- Поле `notes` / комментарии у задачи.
- Время выполнения (`scheduledTime`) и напоминания на задачу.
- Подзадачи / чек-листы внутри задачи.
- Тэги / категории.
- Поиск.
- Undo-toast после удаления.
- Press-эффекты на body строки (только `.contextMenu` long-press).
- Поддержка iPad / Mac Catalyst.
- Кастомные звуковые эффекты.

---

## 16. Изменения для CLAUDE.md (синхронизация)

После утверждения спека следует обновить `DailyFlow/CLAUDE.md`:

1. **Раздел «Структура файлов»** — добавить:
   - `Views/Today/TodayContentView.swift`
   - `Views/Today/AddTaskBarView.swift`
   - `Views/Today/RolloverBannerView.swift`
   - `Services/TaskService.swift`
   - `Extensions/Haptics.swift`
   - `Extensions/Date+StartOfDay.swift`
   - `Extensions/PreviewContainer.swift`
   - `DailyFlowTests/` (целиком)

2. **Раздел «Карта Models»** — переименовать `isDone` → `isCompleted`, добавить `completedAt: Date?`.

3. **Раздел «Выполненные фичи»** — после реализации экрана отметить:
   - `[x] Экран «Сегодня»`

4. **Раздел «Статус»** — обновить.

---

## 17. Зависимости (что должно быть готово перед экраном «Сегодня»)

Экран использует токены и модификаторы дизайн-системы. Они в текущей кодовой базе пустые (`// TODO: implement`). План реализации должен начинаться с их создания.

### 17.1. `Extensions/ColorExtensions.swift`

```swift
extension Color {
    static let bgPrimary    = Color(hex: 0x0D0D0D)
    static let bgCard       = Color(hex: 0x1A1A1A)
    static let accentTeal   = Color(hex: 0x2DD4A0)
    static let accentAmber  = Color(hex: 0xF0A23B)
    static let accentPurple = Color(hex: 0x9B8AE8)
    static let textPrimary  = Color(hex: 0xF2F2F2)
    static let textSecondary = Color(hex: 0x888888)
    static let textGhost    = Color(hex: 0x666666)

    init(hex: UInt32) { /* стандартный init из rgba */ }
}
```

### 17.2. `Extensions/ViewExtensions.swift`

```swift
extension View {
    func dfTitle()   -> some View { font(.system(size: 21, weight: .medium)).foregroundStyle(Color.textPrimary) }
    func dfBody()    -> some View { font(.system(size: 13, weight: .regular)).foregroundStyle(Color.textPrimary) }
    func dfCaption() -> some View {
        font(.system(size: 10, weight: .regular))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.textGhost)
    }
    func dfCard() -> some View {
        padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.bgCard, in: .rect(cornerRadius: 12))
    }
    func dfAccentCard(color: Color) -> some View {
        padding(.horizontal, 16).padding(.vertical, 14)
            .background(color.opacity(0.08), in: .rect(cornerRadius: 12))
            .overlay(alignment: .leading) {
                Rectangle().fill(color).frame(width: 3).padding(.vertical, 4)
            }
    }
}
```

### 17.3. `Extensions/Date+StartOfDay.swift`

```swift
extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}
```

### 17.4. `Extensions/Haptics.swift`

См. секцию 11.

### 17.5. `App/DailyFlowApp.swift` и `App/ContentView.swift`

Минимально:
- `DailyFlowApp` создаёт `ModelContainer` со всеми `@Model` (`DailyTask`, `Habit`, `HabitLog`, `JournalEntry`).
- `ContentView` — `TabView` с 4 вкладками, на месте «Сегодня» подключён `TodayView`. Остальные три — `Text("Скоро")` заглушки.
- Стиль таб-бара: фон `.bgPrimary`, активная иконка `.textPrimary`, неактивная `.textGhost`.

---

## 18. Готовность к реализации

✅ Все архитектурные решения зафиксированы.
✅ Все API сигнатуры выписаны.
✅ Все edge cases пройдены.
✅ Тестовая стратегия определена.
✅ Зависимости (дизайн-токены, модификаторы, app-каркас) перечислены.
✅ Out-of-scope зафиксирован.

Следующий шаг: `superpowers:writing-plans` — детальный пошаговый план реализации с чек-листом и порядком файлов.
