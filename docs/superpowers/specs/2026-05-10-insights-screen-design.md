# Спецификация: Экран «Инсайты» (DailyFlow)

**Дата:** 2026-05-10
**Статус:** утверждён, готов к написанию плана реализации
**Платформа:** iOS 26+, Swift 6, SwiftUI + SwiftData + Swift Charts
**Связанные документы:** `CLAUDE.md`, `docs/superpowers/specs/2026-05-07-today-screen-design.md`, `docs/superpowers/specs/2026-05-09-habits-screen-design.md`

---

## 1. Цель экрана

Четвёртый из четырёх экранов TabView. Показывает агрегированную статистику пользователя за **скользящие последние 7 дней** (`[today−6 … today]`):

- Три ключевые метрики: % выполненных задач, % выполненных привычек, среднее настроение.
- Топ-3 текущих стриков по привычкам.
- Гистограмма настроения по дням.
- Empty state, пока в окне набралось менее 3 дней с данными.

Архитектурный паттерн совпадает с Today/Habits: **Pure SwiftUI + `@Query` + `InsightsService`-namespace**, без отдельного слоя ViewModel.

---

## 2. Журнал решений

| № | Вопрос | Решение |
|---|---|---|
| Q1 | Период метрик | Скользящие 7 дней `[today−6 … today]` (rolling) |
| Q2 | Расчёт «% задач» | `closed / total` среди задач с `date ∈ window`. nil, если задач 0. |
| Q3 | Расчёт «% привычек» | `Σ logs / Σ min(7, daysSinceCreated+1)` — знаменатель учитывает `Habit.createdAt` |
| Q4 | Расчёт «среднее настроение» | Простое среднее `moodScore`. Формат «`4.2 / 5`». Прочерк при отсутствии записей |
| Q5 | «Лучшие стрики» | Топ-3 текущих стриков (`HabitService.streak`), `value > 0`. Секция скрывается, если пусто |
| Q6 | Гистограмма настроения | Swift Charts `BarMark`, домен Y `0...5`, цвет `accentPurple`, подпись X — числа дней. Дни без записи — пустой слот |
| Q7 | Empty state | Порог < 3 уникальных дней с данными в окне. Текст по центру, без иллюстраций |
| Q8 | Порядок секций | Заголовок → 3 метрики горизонтально → лучшие стрики → гистограмма настроения |
| Q9 | Cross-midnight | Двухслойная View `InsightsView` + `InsightsContentView` с `.id(dateAnchor)`, как на Today |
| Q10 | Сервисный слой | `InsightsService`-namespace, stateless, `ModelContext` принимается явно |
| A | Архитектурный подход | **`ScrollView` + `@Query` + `InsightsService`-namespace** |

---

## 3. Модели данных

Изменений **не требуется**. Используются существующие поля:

- `DailyTask.date`, `DailyTask.isCompleted`
- `Habit.createdAt`, `Habit.colorHex`, `Habit.name`, `Habit.logs`
- `HabitLog.date`, `HabitLog.habit`
- `JournalEntry.date`, `JournalEntry.moodScore`

Все даты в БД хранятся через `Calendar.current.startOfDay(for:)` — это уже инвариант моделей.

---

## 4. Сервисный слой: `InsightsService`

`enum`-namespace со статическими функциями. Принимает `ModelContext` явным параметром. Stateless, чисто-вычислительный (никаких `insert`/`delete`/`save`).

### 4.1. Внутреннее окно

Все функции принимают `today: Date` и сами вычисляют окно:

```swift
let end   = Calendar.current.startOfDay(for: today)
let start = Calendar.current.date(byAdding: .day, value: -6, to: end)!
// Окно: [start ... end] включительно, длина 7 дней.
```

Передача `today` параметром (а не использование `.now`) делает функции детерминированными и тестируемыми.

### 4.2. API

```swift
enum InsightsService {

    /// Доля выполненных задач за окно. nil, если в окне нет задач.
    static func tasksRate(today: Date, in ctx: ModelContext) -> Double?

    /// Доля выполненных привычек.
    /// Знаменатель = Σ по привычкам min(7, daysSinceCreated+1).
    /// Числитель = количество HabitLog в окне (с date >= habit.createdAt.startOfDay).
    /// nil если знаменатель == 0 (нет привычек или все созданы после today).
    static func habitsRate(today: Date, in ctx: ModelContext) -> Double?

    /// Простое среднее JournalEntry.moodScore за окно. nil, если 0 записей.
    static func averageMood(today: Date, in ctx: ModelContext) -> Double?

    /// Топ-N привычек по value текущего стрика.
    /// Использует HabitService.streak(for:relativeTo:).
    /// Фильтрует value > 0; сортирует по убыванию value.
    static func topStreaks(limit: Int, today: Date, in ctx: ModelContext)
        -> [(habit: Habit, value: Int, isActive: Bool)]

    /// Ровно 7 элементов в порядке возрастания дат: от today−6 до today.
    /// score == nil → нет записи в этот день (пустой слот в графике).
    static func moodSeries(today: Date, in ctx: ModelContext)
        -> [(date: Date, score: Int?)]

    /// Количество уникальных дней в окне, имеющих хотя бы одну запись
    /// в DailyTask, HabitLog или JournalEntry. Empty state когда < 3.
    static func uniqueDataDays(today: Date, in ctx: ModelContext) -> Int
}
```

### 4.3. Инварианты

1. Все даты внутри сервиса нормализуются через `Calendar.current.startOfDay(for:)`.
2. Окно вычисляется один раз в начале каждой функции.
3. Все функции — чистые: не мутируют данные, не вызывают `ctx.save()`.
4. Все методы выполняются на main actor (`ModelContext` main-bound).
5. `topStreaks` исключает `value == 0` — нулевой стрик не показывается; во View секция при пустом результате скрывается.
6. `moodSeries` возвращает ровно 7 элементов, отсортированных по дате возрастающе.
7. `habitsRate` исключает «ретроактивные» `HabitLog` с `log.date < habit.createdAt.startOfDay` — из числителя и знаменателя.
8. Будущие задачи (`date > today`) не учитываются (окно `[today−6 … today]`).

### 4.4. Псевдокод ключевых формул

**`tasksRate`:**
```
tasks = fetch DailyTask where date in [start...end]
if tasks.isEmpty { return nil }
return Double(tasks.count where isCompleted) / Double(tasks.count)
```

**`habitsRate`:**
```
habits = fetch Habit
denom = 0
for h in habits:
    createdDay = h.createdAt.startOfDay
    if createdDay > end: continue                       // создана после окна
    daysCovered = days_between(max(createdDay, start), end) + 1
    denom += min(7, daysCovered)
if denom == 0: return nil

numer = count of HabitLog where:
    log.date in [start...end]
    AND log.date >= log.habit.createdAt.startOfDay
return Double(numer) / Double(denom)
```

**`averageMood`:**
```
entries = fetch JournalEntry where date in [start...end]
if entries.isEmpty { return nil }
return Double(entries.map(\.moodScore).reduce(0, +)) / Double(entries.count)
```

**`uniqueDataDays`:**
```
dates = Set<Date>()
dates.formUnion(DailyTask    where date in window → map(date))
dates.formUnion(HabitLog     where date in window → map(date))
dates.formUnion(JournalEntry where date in window → map(date))
return dates.count
```

---

## 5. Файловая иерархия

```
DailyFlow/Views/Insights/
  InsightsView.swift             ≤  40 строк   обёртка scenePhase + dateAnchor
  InsightsContentView.swift      ≤ 130 строк   ScrollView + секции + empty state
  MetricCardView.swift           ≤  80 строк   1 карточка из 3 (число + бар + лейбл)
  StreakRowView.swift            ≤  50 строк   строка топ-стрика
  MoodChartView.swift            ≤  80 строк   гистограмма Swift Charts
  EmptyInsightsView.swift        ≤  40 строк   2 строки текста по центру

DailyFlow/Services/
  InsightsService.swift          ≤ 150 строк   новый файл

DailyFlow/Extensions/
  ViewExtensions.swift           +5 строк      добавить модификатор .dfStat()

DailyFlow/App/
  ContentView.swift              ~3 строки     заменить placeholder на InsightsView()

DailyFlow/Extensions/
  PreviewContainer.swift         +20 строк     добавить сценарий .fullWeek

DailyFlowTests/Services/
  InsightsServiceTests.swift     ~150 строк    Swift Testing
```

Synchronized folder references (Xcode 26) автоматически добавят новые `.swift` в нужные таргеты.

---

## 6. UI и компоненты

### 6.1. Раскладка `InsightsContentView`

```
ScrollView (vertical) bgPrimary
└── VStack(spacing: 16, alignment: .leading)
    ├── Text("Инсайты").dfTitle()
    │     .padding(.horizontal, 16).padding(.top, 8)
    │
    ├── if uniqueDataDays < 3:
    │     EmptyInsightsView()
    │       .frame(maxWidth: .infinity, maxHeight: .infinity)
    │
    └── else:
        ├── HStack(spacing: 12) {                    // 3 метрики горизонтально
        │       MetricCardView(.tasks,  rate: tasksRate)
        │       MetricCardView(.habits, rate: habitsRate)
        │       MetricCardView(.mood,   value: averageMood)
        │   }
        │   .padding(.horizontal, 16)
        │
        ├── if !topStreaks.isEmpty {
        │       VStack(alignment: .leading, spacing: 8) {
        │           Text("ЛУЧШИЕ СТРИКИ").dfCaption()
        │           VStack(spacing: 12) {
        │               ForEach(topStreaks) { StreakRowView($0) }
        │           }
        │           .dfCard()
        │       }
        │       .padding(.horizontal, 16)
        │   }
        │
        └── VStack(alignment: .leading, spacing: 8) {
                Text("НАСТРОЕНИЕ — ПОСЛЕДНИЕ 7 ДНЕЙ").dfCaption()
                MoodChartView(series: moodSeries, today: today).dfCard()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
```

Глобальный фон — `Color.bgPrimary`. Отступов сверху нет (заголовок уходит под safe area top, как у Today/Habits).

### 6.2. `MetricCardView`

```
┌──────────────────┐
│ ЗАДАЧИ           │   .dfCaption()
│                  │
│ 75%              │   .dfStat() — 28pt .semibold, accent*
│                  │
│ ▰▰▰▰▰▰▱▱▱▱       │   полоса 3pt
│                  │
│ закрыто за 7 дн. │   .dfLabel()
└──────────────────┘
```

```swift
enum MetricKind {
    case tasks   // accentTeal,   "ЗАДАЧИ",     "закрыто за 7 дн."
    case habits  // accentAmber,  "ПРИВЫЧКИ",   "выполнено за 7 дн."
    case mood    // accentPurple, "НАСТРОЕНИЕ", "среднее за 7 дн."
}

struct MetricCardView: View {
    let kind: MetricKind
    /// .tasks/.habits → rate ∈ [0...1]; .mood → avg ∈ [1...5]; nil → "—"
    let value: Double?
}
```

**Форматирование числа:**

- `.tasks`/`.habits`: `String(format: "%.0f%%", rate * 100)`. Прогресс-бар: `progress = rate`.
- `.mood`: `String(format: "%.1f", avg) + " / 5"` (формат «4.2 / 5», подпись «/ 5» — 13pt `.regular`, цвет `textSecondary`). Прогресс-бар: `progress = (avg − 1) / 4`.
- `value == nil`: символ `"—"` цвета `textGhost`, прогресс-бар пустой (только серый фон).

**Прогресс-бар:**

```swift
GeometryReader { geo in
    ZStack(alignment: .leading) {
        Rectangle().fill(Color.bgPixelInactive)
        Rectangle().fill(accent).frame(width: max(0, geo.size.width * progress))
    }
}
.frame(height: 3)
.clipShape(.rect(cornerRadius: 1.5))
```

Без анимаций, без градиентов. Карточка занимает 1/3 ширины через `.frame(maxWidth: .infinity)` внутри `HStack(spacing: 12)`.

### 6.3. `StreakRowView`

```
●  Утренняя пробежка                         12
```

```swift
struct StreakRowView: View {
    let habit: Habit
    let value: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color(hex: habit.colorHex)).frame(width: 8, height: 8)
            Text(habit.name).dfBody()
            Spacer()
            Text("\(value)")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? Color(hex: habit.colorHex) : Color.textGhost)
        }
        .frame(height: 36)
    }
}
```

### 6.4. `MoodChartView`

```swift
import Charts

struct MoodChartView: View {
    let series: [(date: Date, score: Int?)]   // ровно 7
    let today: Date

    var body: some View {
        Chart(series, id: \.date) { point in
            if let score = point.score {
                BarMark(
                    x: .value("День", point.date, unit: .day),
                    y: .value("Настроение", score)
                )
                .foregroundStyle(Color.accentPurple)
                .cornerRadius(2)
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
                            .foregroundStyle(Calendar.current.isDate(date, inSameDayAs: today)
                                             ? Color.textPrimary : Color.textGhost)
                    }
                }
            }
        }
        .frame(height: 120)
    }
}
```

Все бары — `accentPurple`, `cornerRadius(2)`. Дни без записи — пустой слот (Mark не добавляется). Подпись сегодняшнего дня — `textPrimary`, остальные — `textGhost`.

### 6.5. `EmptyInsightsView`

```swift
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
```

Без иконок, кнопок, иллюстраций.

### 6.6. Двухслойная View

```swift
struct InsightsView: View {
    @Environment(\.scenePhase) private var phase
    @State private var dateAnchor = Calendar.current.startOfDay(for: .now)

    var body: some View {
        InsightsContentView(today: dateAnchor)
            .id(dateAnchor)
            .onChange(of: phase) { _, new in
                if new == .active {
                    let now = Calendar.current.startOfDay(for: .now)
                    if now != dateAnchor { dateAnchor = now }
                }
            }
    }
}
```

`InsightsContentView` принимает `today: Date` параметром. Внутри объявлены три `@Query` без предикатов:

```swift
@Query private var allTasks: [DailyTask]
@Query private var allHabits: [Habit]
@Query private var allJournalEntries: [JournalEntry]
```

**Назначение `@Query` здесь — исключительно реактивный триггер**: при любом изменении в БД View пересоздаётся, и сервисные функции пересчитывают агрегаты. Сами `@Query`-массивы во View не используются для фильтрации/сортировки. Фильтрация по окну `[today−6 … today]` и расчёты — целиком внутри `InsightsService`, через `ctx.fetch(_:)` с предикатами. Это:

- Делает сервис детерминированным и легко тестируемым (тесты не зависят от `@Query`).
- Сохраняет инвариант «бизнес-логика в сервисе, View рендерит».

Цена — двойной фетч (один через `@Query`, второй через `ctx.fetch`). Для текущих объёмов данных (десятки/сотни записей) это пренебрежимо. Если станет узким местом — отдельная оптимизация, не часть этой спецификации.

Обращение к `ModelContext` во View — через `@Environment(\.modelContext) private var ctx`.

---

## 7. Дизайн-система: новый токен

### 7.1. Типографика — добавляется

| Роль | Размер | Вес | Использование |
|---|---|---|---|
| **Stat** | **28pt** | **`.semibold`** | Большая цифра в `MetricCardView` |

Реализация — новый модификатор в `ViewExtensions.swift`:

```swift
func dfStat() -> some View {
    font(.system(size: 28, weight: .semibold))
}
```

Цвет применяется отдельно: `Text("75%").dfStat().foregroundStyle(Color.accentTeal)`.

После реализации эта строка добавляется в раздел «Дизайн-система → Типографика» в `CLAUDE.md`.

### 7.2. Палитра — без изменений

Используются существующие токены: `bgPrimary`, `bgCard`, `bgPixelInactive`, `accentTeal`, `accentAmber`, `accentPurple`, `textPrimary`, `textSecondary`, `textGhost`.

---

## 8. Тесты

`InsightsServiceTests.swift` (Swift Testing, in-memory `ModelContainer` через `TestContainer.make()`).

Все тесты используют **фиксированную** `today: Date` (например, `Date(timeIntervalSince1970: 1_762_473_600)`), а не `.now`, для детерминированности.

`TestContainer.make()` уже регистрирует все 4 модели (`DailyTask`, `Habit`, `HabitLog`, `JournalEntry`) — изменений схемы не требуется.

### План тестов (20 тестов)

**`tasksRate` (4):**
1. `tasksRate_returnsNil_whenNoTasksInWindow`
2. `tasksRate_excludesTasksOutsideWindow` — `date == today − 7` не учитывается; `date == today` учитывается
3. `tasksRate_returnsCorrectFraction` — 5 задач, 3 закрыты → 0.6
4. `tasksRate_ignoresFutureTasks` — `date == today + 1` не учитывается

**`habitsRate` (4):**
5. `habitsRate_returnsNil_whenNoHabits`
6. `habitsRate_returnsNil_whenAllHabitsCreatedAfterToday`
7. `habitsRate_usesFullWindow_forOldHabits` — `createdAt == today − 30`, 7 логов в окне → 1.0
8. `habitsRate_partialWindow_forNewHabit` — `createdAt == today − 2`, 2 лога → 2 / 3 ≈ 0.667

**`averageMood` (3):**
9. `averageMood_returnsNil_whenNoEntries`
10. `averageMood_simpleAverage` — `[4, 3, 5]` → 4.0
11. `averageMood_excludesEntriesOutsideWindow`

**`topStreaks` (3):**
12. `topStreaks_emptyArray_whenNoHabits`
13. `topStreaks_filtersOutZeroStreaks`
14. `topStreaks_sortedDescending_andLimited` — 5 привычек со стриками `[12, 7, 3, 2, 0]`, `limit: 3` → `[12, 7, 3]`

**`moodSeries` (3):**
15. `moodSeries_returnsExactlySevenEntries` — даже при пустой БД массив длиной 7
16. `moodSeries_orderedFromOldestToToday` — `series.first.date == today − 6`, `series.last.date == today`
17. `moodSeries_mapsScoresToCorrectDays`

**`uniqueDataDays` (3):**
18. `uniqueDataDays_zero_whenNoData`
19. `uniqueDataDays_countsAcrossAllEntities` — task сегодня + log вчера + entry сегодня → 2
20. `uniqueDataDays_excludesOutsideWindow`

UI не тестируется (политика проекта — Today/Habits тоже без UI-тестов).

---

## 9. Превью

Каждый View получает `#Preview`, обёрнутый в `.preferredColorScheme(.dark)` и фон `Color.bgPrimary`:

- **`InsightsView`** — 2 preview через `PreviewContainer`-сценарии:
  - `.empty` — пустая БД → empty state.
  - `.fullWeek` — **новый сценарий**: 7 дней задач (часть закрыта), 3 привычки с разными стриками и `createdAt`, 5 записей дневника со score 3–5.
- **`MetricCardView`** — `HStack` из 4 кейсов: `.tasks` 75%, `.habits` 62%, `.mood` 4.2, `.mood` `nil` (прочерк).
- **`StreakRowView`** — 2 кейса: активный (цветная цифра) и неактивный (серая).
- **`MoodChartView`** — 2 кейса: полная неделя (7 баров) и неделя с 2 пустыми слотами.
- **`EmptyInsightsView`** — один preview.

---

## 10. Сторонние изменения

1. **`ContentView.swift`** — заменить placeholder под вкладкой «Инсайты» на `InsightsView()`. Иконка `chart.bar` остаётся.
2. **`PreviewContainer.swift`** — добавить сценарий `.fullWeek`.
3. **`ViewExtensions.swift`** — добавить `.dfStat()`.
4. **`CLAUDE.md`** (после имплементации):
   - Раздел «Статус»: «экраны Сегодня, Привычки, Инсайты реализованы. Осталось: Дневник».
   - Раздел «Дизайн-система → Типографика»: добавить строку `Stat / 28pt / .semibold`.
   - Раздел «Выполненные фичи»: чек у пункта «Экран Инсайты».
   - Раздел «Структура файлов»: дополнить дерево `Views/Insights/`.

---

## 11. Out of scope (явно)

- Переключатель периода `Неделя / Месяц / Всё время`.
- Исторический максимум стриков, экран «Достижения».
- Цветовые градации столбиков по значению настроения.
- Анимации появления цифр / прогресс-баров / баров графика.
- Pull-to-refresh (данные локальные, `@Query` реактивен).
- Шеринг скриншота инсайтов, экспорт CSV.
- Тапы по элементам инсайтов с переходом на детальный экран.
- Учёт часовых поясов при пересечении полуночи (используется текущая системная timezone).

---

## 12. Acceptance criteria

- [ ] Build succeeded, 0 warnings (`/build`).
- [ ] Lint clean (`/lint`).
- [ ] Format clean (`/format` без изменений).
- [ ] 20 тестов `InsightsServiceTests` проходят.
- [ ] При первом запуске (пустая БД) экран показывает empty state «Нужно ещё немного данных».
- [ ] При наличии 3+ дней с данными показываются: заголовок, 3 метрики горизонтально, секция стриков (если есть `value > 0`), гистограмма настроения.
- [ ] Закрытие задачи на Today реактивно меняет цифру `% задач` (через `@Query`).
- [ ] Toggle привычки на Habits реактивно меняет `% привычек` и топ стриков.
- [ ] Cross-midnight: при возврате в приложение после полуночи окно сдвигается (`InsightsContentView` пересоздаётся через `.id(dateAnchor)`).
- [ ] Все View ≤ 150 строк.
- [ ] `#Preview` есть в каждом новом View.
