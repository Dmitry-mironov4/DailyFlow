# Спецификация: Экран «Привычки» (DailyFlow)

**Дата:** 2026-05-09
**Статус:** утверждён, готов к написанию плана реализации
**Платформа:** iOS 26+, Swift 6, SwiftUI + SwiftData
**Связанные документы:** `DailyFlow/CLAUDE.md`, `docs/superpowers/specs/2026-05-07-today-screen-design.md`

---

## 1. Цель экрана

Второй из четырёх экранов TabView. Позволяет:
- Отслеживать ежедневные привычки с визуальным прогрессом за 7 дней.
- Отмечать привычки выполненными (toggle по всей карточке).
- Добавлять, редактировать и удалять привычки.
- Менять порядок привычек через drag-to-reorder.

Архитектурный паттерн совпадает с экраном «Сегодня»: Pure SwiftUI + `@Query` + `HabitService`-namespace, без отдельного слоя ViewModel.

---

## 2. Журнал решений

| № | Вопрос | Решение |
|---|---|---|
| Q1 | Механизм toggle | Тап по всей карточке целиком |
| Q2 | Визуальное состояние выполненной привычки | `.dfAccentCard(color:)` (левый цветной бордер) — не выполнена: `.dfCard()` |
| Q3 | Расчёт стрика | Последовательные дни подряд включая сегодня. Если сегодня не выполнено — показывать вчерашнее значение серым (мотивация). |
| Q4 | Цвета PixelGrid | Выполнено — цвет привычки, не выполнено — `#333333` |
| Q5 | Редактирование привычки | `.contextMenu` с пунктами «Изменить» и «Удалить» |
| Q6 | Сортировка | `sortOrder: Int` + drag-to-reorder через `List.onMove` |
| Q7 | Empty state | Только ghost-кнопка «Добавить привычку», без иллюстраций |
| A | Архитектурный подход | **`List` + `@Query(sort: \.sortOrder)` + `HabitService`-namespace** |

---

## 3. Модели данных

Модели уже реализованы и не требуют изменений.

### `Habit` (`@Model`)

```swift
@Model
final class Habit {
    var id: UUID
    var name: String
    var colorHex: String        // "2DD4A0" / "F0A23B" / "9B8AE8"
    var sortOrder: Int
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog]
}
```

### `HabitLog` (`@Model`)

```swift
@Model
final class HabitLog {
    var id: UUID
    var date: Date              // ВСЕГДА startOfDay
    var completedAt: Date
    var habit: Habit?
}
```

**Инвариант:** на одну дату — не более одного `HabitLog` на привычку. `HabitService.toggleToday` проверяет это перед вставкой.

---

## 3. Сервисный слой: `HabitService`

`enum`-namespace со статическими функциями. Принимает `ModelContext` явным параметром. Stateless.

### 3.1. API

```swift
enum HabitService {
    /// Возвращает nil если name после trim пустой.
    /// sortOrder = (max существующего) + 1.
    @discardableResult
    static func add(name: String, colorHex: String, in ctx: ModelContext) -> Habit?

    /// Пустой name игнорируется (откат). colorHex применяется всегда.
    static func update(_ habit: Habit, name: String, colorHex: String, in ctx: ModelContext)

    /// Каскадное удаление: deleteRule .cascade на logs обрабатывает HabitLog автоматически.
    static func delete(_ habit: Habit, in ctx: ModelContext)

    /// Пересчитывает sortOrder всех привычек после drag-to-reorder.
    static func reorder(_ habits: [Habit], from source: IndexSet, to dest: Int, in ctx: ModelContext)

    /// Создаёт HabitLog на сегодня если его нет; удаляет если есть (toggle).
    static func toggleToday(_ habit: Habit, in ctx: ModelContext)

    /// Возвращает стрик и флаг активности.
    /// isActive == true → сегодня выполнено (цифра цветная).
    /// isActive == false → сегодня не выполнено, value = стрик за вчера (цифра серая).
    static func streak(for habit: Habit, relativeTo date: Date) -> (value: Int, isActive: Bool)

    /// Выполнена ли привычка на конкретный день (для PixelGrid).
    static func isDone(_ habit: Habit, on date: Date) -> Bool
}
```

### 3.2. Инварианты

1. Все `date` нормализуются через `startOfDay` на входе.
2. `toggleToday` атомарен: fetch → если лог есть — delete, если нет — insert.
3. `streak` не мутирует данные — чистая вычислительная функция.
4. `add` с пустым `name.trimmingCharacters(in: .whitespacesAndNewlines)` возвращает `nil`.
5. `reorder` перезаписывает `sortOrder` всем элементам в новом порядке (0, 1, 2, …).
6. Все методы выполняются на main actor (`ModelContext` main-bound).

### 3.3. Логика `streak`

```
let today = date.startOfDay
if isDone(habit, on: today):
    считать назад от today пока isDone → value, isActive = true
else:
    считать назад от yesterday пока isDone → value, isActive = false
```

---

## 4. Файловая иерархия

```
DailyFlow/Views/Habits/
  HabitsView.swift          ≤ 120 строк   List + @Query + drag + sheet
  HabitCardView.swift       ≤ 100 строк   карточка с toggle + contextMenu
  PixelGridView.swift       ≤  60 строк   7 квадратов 28×28
  AddHabitSheet.swift       ≤  80 строк   TextField + 3 цветовые кнопки

DailyFlow/Services/
  HabitService.swift        ≤ 120 строк   новый файл

DailyFlowTests/Services/
  HabitServiceTests.swift   ~80 строк     Swift Testing
```

---

## 5. Управление состоянием

### 5.1. `HabitsView`

```swift
struct HabitsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    @State private var showAdd = false
    @State private var editingHabit: Habit?   // nil → режим создания, non-nil → редактирование

    var body: some View {
        List {
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

            // Ghost-кнопка добавления (inline, не отдельный файл)
            Button { showAdd = true } label: {
                AddHabitGhostRow()
            }
                .listRowBackground(Color.bgPrimary)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
        .listStyle(.plain)
        .background(Color.bgPrimary)
        .sheet(isPresented: $showAdd) {
            AddHabitSheet(habit: nil, onSave: { name, hex in
                HabitService.add(name: name, colorHex: hex, in: ctx)
            })
        }
        .sheet(item: $editingHabit) { habit in
            AddHabitSheet(habit: habit, onSave: { name, hex in
                HabitService.update(habit, name: name, colorHex: hex, in: ctx)
            })
        }
    }
}
```

### 5.2. Производные значения (вычисляются в `HabitCardView.body`)

```swift
private var isDoneToday: Bool { HabitService.isDone(habit, on: .now) }
private var streak: (value: Int, isActive: Bool) { HabitService.streak(for: habit, relativeTo: .now) }
private var accentColor: Color { Color(hex: habit.colorHex) }
```

---

## 6. Спецификации компонентов

### 6.1. `HabitCardView`

- Стиль: `.dfCard()` если не выполнена сегодня, `.dfAccentCard(color: accentColor)` если выполнена.
- Анимация: `.animation(.easeInOut(duration: 0.2), value: isDoneToday)`.
- Левая часть: название — `.dfBody()`, под ним `PixelGridView(habit: habit)`.
- Правая часть: цифра стрика — `Text("\(streak.value)")` — 21pt `.medium`, цвет `accentColor` если `streak.isActive`, `Color.textSecondary` если нет. Анимация цвета: `.animation(.easeInOut(duration: 0.2), value: streak.isActive)`.
- Тап по всей карточке → `onToggle`. Хаптика: `.medium` при toggle on, `.light` при toggle off.
- `.contextMenu`:
  - «Изменить» → `onEdit`
  - «Удалить» (`.destructive`) → `onDelete` + `Haptics.tap(.heavy)`
- `.swipeActions(edge: .trailing, allowsFullSwipe: true)`:
  - «Удалить» (`.destructive`, иконка `trash`) → `onDelete` + `Haptics.tap(.heavy)`

### 6.2. `PixelGridView`

```swift
struct PixelGridView: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 4) {
            ForEach(lastSevenDays, id: \.self) { date in
                RoundedRectangle(cornerRadius: 4)
                    .fill(HabitService.isDone(habit, on: date)
                          ? Color(hex: habit.colorHex)
                          : Color(hex: "333333"))
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
```

Дни до `habit.createdAt` показываются серыми (`#333333`) — `isDone` вернёт `false`.

### 6.3. `AddHabitSheet`

- Принимает `habit: Habit?` (nil = создание, non-nil = редактирование) и `onSave: (String, String) -> Void`.
- `@State var name: String` — инициализируется из `habit?.name ?? ""`.
- `@State var selectedHex: String` — инициализируется из `habit?.colorHex ?? "2DD4A0"`.
- `TextField("Название привычки", text: $name)` — `.dfBody()`, autofocus (`.focused($isFocused)` + `.onAppear { isFocused = true }`).
- Три цветовые кнопки в `HStack(spacing: 12)` — круги 32×32:
  - `"2DD4A0"` (teal), `"F0A23B"` (amber), `"9B8AE8"` (purple).
  - Выбранный: `strokeBorder(Color(hex: hex), lineWidth: 2)` + `Circle().fill(Color(hex: hex))`.
  - Невыбранный: `Circle().fill(Color(hex: hex)).opacity(0.4)`.
- Кнопка «Добавить» / «Сохранить»: задизейблена если `name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`.
- По нажатию: `Haptics.tap(.light)` → `onSave(name, selectedHex)` → `dismiss()`.

### 6.4. Ghost-кнопка добавления (нет отдельного файла)

Инлайновая `View` внутри `HabitsView`. Текст «Добавить привычку», цвет `accentTeal`, стиль аналогичен `AddTaskBarView` из экрана «Сегодня» (иконка `plus`, `.dfBody()`). Тап → `showAdd = true`.

---

## 7. Взаимодействия — сводная таблица

| Элемент | Жест | Действие | Хаптика |
|---|---|---|---|
| Карточка привычки | tap | `toggleToday` | `.medium` (on) / `.light` (off) |
| Карточка привычки | long-press | `.contextMenu` | — |
| «Изменить» в меню | tap | `editingHabit = habit` → sheet | — |
| «Удалить» в меню | tap | `HabitService.delete` | `.heavy` |
| Trailing swipe | full swipe | `HabitService.delete` | `.heavy` |
| Drag handle | drag | `.onMove` → `HabitService.reorder` | системная |
| Ghost-кнопка | tap | `showAdd = true` | — |
| Sheet «Сохранить» | tap | `add` или `update` | `.light` |

---

## 8. Анимации

| Что | Trigger | Animation |
|---|---|---|
| Стиль карточки `.dfCard` ↔ `.dfAccentCard` | `isDoneToday` | `.easeInOut(duration: 0.2)` |
| Цвет цифры стрика | `streak.isActive` | `.easeInOut(duration: 0.2)` |
| Последний пиксель PixelGrid | `isDoneToday` | `.easeInOut(duration: 0.15)` |
| Удаление / reorder строки | List | стандартная List-анимация |

**Запрещено:** scale-bounce, rotation, blur — строго по дизайн-системе.

---

## 9. Edge cases

| Сценарий | Поведение |
|---|---|
| Toggle дважды подряд | Идемпотентно: второй вызов удаляет лог, третий — создаёт снова |
| Пустой name в sheet | Кнопка «Сохранить» задизейблена |
| Удалить привычку с логами | `deleteRule: .cascade` — логи удаляются автоматически |
| Стрик при первом дне | 1 если сегодня выполнено, 0 (серым) если ещё нет |
| PixelGrid при создании сегодня | Первые N квадратов (до createdAt) — `#333333`, остальные по факту |
| Drag во время открытого sheet | Sheet блокирует List, drag невозможен |
| `colorHex` не из трёх стандартных | `Color(hex:)` обрабатывает любой hex — не упадёт |
| Несколько логов на одну дату | `toggleToday` проверяет через fetch: если лог есть — удаляет первый найденный |
| Привычек нет | List показывает только ghost-кнопку добавления |

---

## 10. Empty state

Нет ни одной привычки → `List` содержит только ghost-кнопку «Добавить привычку». Никаких иллюстраций, иконок, поясняющего текста.

---

## 11. Тестирование

### 11.1. Стек

**Swift Testing** (нативный для iOS 26+ / Swift 6). Не XCTest. In-memory `ModelContainer` через существующий `TestContainer.make()`.

### 11.2. Минимальный набор `HabitServiceTests`

```swift
@Suite("HabitService") @MainActor
struct HabitServiceTests {
    @Test func add_returnsNilForEmptyName() throws { }
    @Test func add_assignsIncrementingSortOrder() throws { }
    @Test func toggleToday_createsLog() throws { }
    @Test func toggleToday_removesLogOnSecondCall() throws { }
    @Test func toggleToday_idempotentOnThirdCall() throws { }
    @Test func isDone_returnsTrueWhenLogExists() throws { }
    @Test func isDone_returnsFalseWhenNoLog() throws { }
    @Test func streak_returnsZeroAndInactiveWhenNeverDone() throws { }
    @Test func streak_returnsOneAndActiveWhenDoneToday() throws { }
    @Test func streak_returnsYesterdayCountAndInactiveWhenNotDoneToday() throws { }
    @Test func streak_breaksOnMissedDay() throws { }
    @Test func reorder_updatesSortOrder() throws { }
    @Test func delete_cascadesLogs() throws { }
}
```

### 11.3. Превью как «визуальные тесты»

```swift
#Preview("Empty")       { HabitsView().modelContainer(.preview(.empty)) }
#Preview("Three habits"){ HabitsView().modelContainer(.preview(.threeHabits)) }
#Preview("All done")    { HabitsView().modelContainer(.preview(.allHabitsDoneToday)) }
#Preview("Streak")      { HabitsView().modelContainer(.preview(.longStreak)) }
```

Сценарии добавляются в `Extensions/PreviewContainer.swift` — новый `enum case` для привычек.

---

## 12. Out of scope (YAGNI)

- Напоминания / уведомления для привычек (отдельная фича).
- Экран детали привычки (статистика за месяц/год).
- Архивирование привычки (вместо удаления).
- Цветовой picker с произвольным цветом (только 3 стандартных).
- Количество повторений в день (бинарный toggle: сделано / не сделано).
- Цель (например, «3 раза в неделю» вместо ежедневно).
- Экспорт в Obsidian (отдельная фича).
- Поиск/фильтрация привычек.

---

## 13. Изменения для CLAUDE.md (синхронизация)

После реализации обновить `DailyFlow/CLAUDE.md`:

1. **Раздел «Структура файлов»** — заменить заглушки в `Views/Habits/` на финальные файлы, добавить `Services/HabitService.swift`, `DailyFlowTests/Services/HabitServiceTests.swift`.
2. **Раздел «Выполненные фичи»** — отметить `[x] Экран «Привычки»`.
3. **Раздел «Статус»** — обновить на следующий шаг.

---

## 14. Готовность к реализации

✅ Все архитектурные решения зафиксированы.
✅ Все API сигнатуры выписаны.
✅ Все edge cases пройдены.
✅ Тестовая стратегия определена.
✅ Out-of-scope зафиксирован.

Следующий шаг: `superpowers:writing-plans` — детальный пошаговый план реализации.
