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
| Q3 | Расчёт «% привычек» | Среднее «дневной доли»: для каждого дня окна, в котором были активные привычки, считаем `выполненных / активных`, потом среднее. Активная привычка = `createdAt.startOfDay <= day`. nil, если ни одного активного дня. |
| Q4 | Расчёт «настроение %» | Среднее `moodScore`, нормированное в долю: `(avg − 1) / 4`. Формат `84%`. Прочерк при отсутствии записей. Унифицирует все 3 метрики в один формат. |
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
    /// Возвращает значение в [0.0 ... 1.0].
    static func tasksRate(today: Date, in ctx: ModelContext) -> Double?

    /// Среднее «дневной доли выполненных привычек» по окну.
    /// Для каждого дня окна, в котором есть хотя бы одна активная привычка
    /// (createdAt.startOfDay <= day), считаем activeLogs / activeHabits.
    /// Возвращает среднее этих значений в [0.0 ... 1.0]. nil, если ни одного активного дня.
    static func habitsRate(today: Date, in ctx: ModelContext) -> Double?

    /// Среднее настроение, нормированное в долю.
    /// avg = mean(JournalEntry.moodScore) для записей в окне.
    /// rate = (avg − 1) / 4 → ∈ [0.0 ... 1.0].
    /// nil, если 0 записей.
    static func moodRate(today: Date, in ctx: ModelContext) -> Double?

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
7. `habitsRate` исключает «ретроактивные» `HabitLog` с `log.date < habit.createdAt.startOfDay` — такой лог не попадёт в `activeLogs` ни в один день, потому что в этот день привычка ещё не активна.
8. Будущие задачи (`date > today`) не учитываются (окно `[today−6 … today]`).
9. Все три метрики (`tasksRate`, `habitsRate`, `moodRate`) возвращают `Double?` ∈ `[0.0 ... 1.0]` — единый формат.

### 4.4. Псевдокод ключевых формул

**`tasksRate`:**
```
tasks = fetch DailyTask where date in [start...end]
if tasks.isEmpty { return nil }
return Double(tasks.count where isCompleted) / Double(tasks.count)
```

**`habitsRate`** — среднее «дневной доли» по дням, в которых были активные привычки:
```
habits = fetch Habit
dailyRates: [Double] = []
for day in [start...end]:                                // 7 дней
    activeHabits = habits.filter { $0.createdAt.startOfDay <= day }
    if activeHabits.isEmpty: continue                    // день до появления первой привычки
    activeLogs = count of HabitLog where:
        log.date == day
        AND log.habit ∈ activeHabits
    dailyRate = Double(activeLogs) / Double(activeHabits.count)
    dailyRates.append(dailyRate)
if dailyRates.isEmpty: return nil
return dailyRates.reduce(0, +) / Double(dailyRates.count)
```

**Свойства формулы:**
- День, когда выполнено 4 из 4 привычек → `dailyRate = 1.0` за этот день. Среднее тянется к 100%, как ожидает пользователь.
- Новая привычка добавлена сегодня — старые дни её просто не учитывают (`activeHabits` за вчера не включает её). Прошлое не наказывается.
- Метрика устойчива к количеству привычек: 1 привычка или 10 — формула даёт «процент закрытия дня», не штрафует за объём.
- Если все 7 дней — до создания первой привычки (новый юзер с пустым списком) → `nil`.

**`moodRate`:**
```
entries = fetch JournalEntry where date in [start...end]
if entries.isEmpty: return nil
avg = Double(entries.map(\.moodScore).reduce(0, +)) / Double(entries.count)
return (avg − 1) / 4                                     // нормировка [1...5] → [0...1]
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
        │       MetricCardView(kind: .tasks,  rate: tasksRate)
        │       MetricCardView(kind: .habits, rate: habitsRate)
        │       MetricCardView(kind: .mood,   rate: moodRate)
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
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ ЗАДАЧИ           │  │ ПРИВЫЧКИ         │  │ НАСТРОЕНИЕ       │   .dfCaption()
│                  │  │                  │  │                  │
│ 75%              │  │ 62%              │  │ 84%              │   .dfStat()
│                  │  │                  │  │                  │
│ ▰▰▰▰▰▰▱▱▱▱       │  │ ▰▰▰▰▰▱▱▱▱▱       │  │ ▰▰▰▰▰▰▰▰▱▱       │   полоса 3pt
│                  │  │                  │  │                  │
│ закрыто за 7 дн. │  │ в среднем за день│  │ в среднем за 7 дн│   .dfLabel()
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

Все три карточки структурно идентичны.

```swift
enum MetricKind {
    case tasks   // accentTeal,   "ЗАДАЧИ",     "закрыто за 7 дн."
    case habits  // accentAmber,  "ПРИВЫЧКИ",   "в среднем за день"
    case mood    // accentPurple, "НАСТРОЕНИЕ", "в среднем за 7 дн."
}

struct MetricCardView: View {
    let kind: MetricKind
    /// rate ∈ [0.0 ... 1.0]; nil → "—"
    let rate: Double?
}
```

**Форматирование числа** — единое для всех трёх метрик:

- `rate != nil`: `"\(Int((rate * 100).rounded()))%"` → «75%», «62%», «84%». Прогресс-бар: `progress = rate`.
- `rate == nil`: символ `"—"` цвета `textGhost`, прогресс-бар пустой (только серый фон).

Подпись «/ 5» больше не используется. Все три карточки визуально однотипны: лейбл — большое число — бар — описание. Цвет числа и заливки бара различаются по `kind` (teal/amber/purple).

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

### План тестов (21 тест)

**`tasksRate` (4):**
1. `tasksRate_returnsNil_whenNoTasksInWindow`
2. `tasksRate_excludesTasksOutsideWindow` — `date == today − 7` не учитывается; `date == today` учитывается
3. `tasksRate_returnsCorrectFraction` — 5 задач, 3 закрыты → 0.6
4. `tasksRate_ignoresFutureTasks` — `date == today + 1` не учитывается

**`habitsRate` (5):**
5. `habitsRate_returnsNil_whenNoHabits`
6. `habitsRate_returnsNil_whenAllHabitsCreatedAfterToday` — все привычки с `createdAt > today` → нет ни одного активного дня → nil
7. `habitsRate_returnsOne_whenAllHabitsDoneEveryDay` — 2 привычки `createdAt == today − 30`, 14 логов (по 2 на каждый день окна) → среднее `[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]` = 1.0
8. `habitsRate_perDayAveraging` — 2 привычки старые, день 1: 2/2=1.0, день 2: 1/2=0.5, день 3–7: 0/2=0.0 → среднее (1.0+0.5+0+0+0+0+0)/7 ≈ 0.214
9. `habitsRate_excludesDaysBeforeFirstHabit` — привычка создана 2 дня назад, делалась оба дня → среднее `[1.0, 1.0]` = 1.0 (первые 5 дней окна skip, нет активных привычек)

**`moodRate` (3):**
10. `moodRate_returnsNil_whenNoEntries`
11. `moodRate_normalizesToRate` — записи `[5, 5, 5]` → avg = 5.0 → rate = 1.0; записи `[1, 1]` → rate = 0.0; записи `[3]` → rate = 0.5
12. `moodRate_excludesEntriesOutsideWindow` — запись с `date == today − 7` игнорируется

**`topStreaks` (3):**
13. `topStreaks_emptyArray_whenNoHabits`
14. `topStreaks_filtersOutZeroStreaks`
15. `topStreaks_sortedDescending_andLimited` — 5 привычек со стриками `[12, 7, 3, 2, 0]`, `limit: 3` → `[12, 7, 3]`

**`moodSeries` (3):**
16. `moodSeries_returnsExactlySevenEntries` — даже при пустой БД массив длиной 7
17. `moodSeries_orderedFromOldestToToday` — `series.first.date == today − 6`, `series.last.date == today`
18. `moodSeries_mapsScoresToCorrectDays`

**`uniqueDataDays` (3):**
19. `uniqueDataDays_zero_whenNoData`
20. `uniqueDataDays_countsAcrossAllEntities` — task сегодня + log вчера + entry сегодня → 2
21. `uniqueDataDays_excludesOutsideWindow`

**Итого: 21 тест.**

UI не тестируется (политика проекта — Today/Habits тоже без UI-тестов).

---

## 9. Превью

Каждый View получает `#Preview`, обёрнутый в `.preferredColorScheme(.dark)` и фон `Color.bgPrimary`:

- **`InsightsView`** — 2 preview через `PreviewContainer`-сценарии:
  - `.empty` — пустая БД → empty state.
  - `.fullWeek` — **новый сценарий**: 7 дней задач (часть закрыта), 3 привычки с разными стриками и `createdAt`, 5 записей дневника со score 3–5.
- **`MetricCardView`** — `HStack` из 4 кейсов: `.tasks` rate 0.75, `.habits` rate 0.62, `.mood` rate 0.84, `.mood` rate `nil` (прочерк).
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

## 12. Открытые вопросы и риски

Места, в которых первая реализация может потребовать корректировки. Каждый пункт явно — чтобы research-агент мог их проверить до начала кодинга, а не после.

### 12.1. Swift Charts: пустые слоты на iOS 26

**Риск:** В §6.4 предполагается, что отсутствие `BarMark` для дня без записи оставит видимый «пустой слот» благодаря явным `AxisMarks(values: series.map(\.date))`. На iOS 26 поведение `chartXAxis` с пользовательскими `values` нужно проверить — возможно, шкала схлопнется и оставшиеся бары сдвинутся, ломая визуальное соответствие «один день = одна позиция».

**План проверки:**
1. Research-агент читает Apple Docs по `Charts.AxisMarks(values:)` и `chartXScale(domain:)` для iOS 26.
2. Если поведение не гарантировано — fallback: использовать `chartXScale(domain: [series.first.date ... series.last.date])` явно, либо рисовать невидимый `RectangleMark` высоты 0 для пустых дней (чтобы Chart знал об их позиции).
3. Если и это не сработает — отказаться от Swift Charts в пользу ручного `HStack` из 7 `Capsule()`-баров. Это последний резерв, не первый выбор.

### 12.2. Размер шрифта `dfStat` (28pt)

**Контекст:** CLAUDE.md фиксирует только три размера: Title 21, Body 13, Caption 10. Ввод 28pt — нарушение чистоты дизайн-системы. 28pt выбран как **SF Pro Title 2** (системный размер, документированный Apple), а не наугад.

**План проверки:**
1. Имплементатор сначала собирает экран с 28pt.
2. В симуляторе на iPhone 16 Pro визуально оценивает: не «жирно» ли (карточка занимает 1/3 ширины — около 113pt). Если жирно — снизить до 24pt (SF Pro Title 3). Если потерянно — повысить до 32pt.
3. **Финальный размер** фиксируется в `CLAUDE.md` после визуального ревью, а не до.

### 12.3. `@Query` без предикатов на больших объёмах

**Риск:** `InsightsContentView` объявляет три `@Query` без предикатов — на каждое изменение в БД пересоздаётся весь массив. На текущих объёмах (десятки задач, единицы привычек, единицы записей дневника) — невидимо. Если пользователь накопит 1000+ задач за год — может стать заметным лагом.

**Решение:**
- В первой версии — оставляем как есть. YAGNI.
- В CLAUDE.md → «Известные проблемы» — добавить заметку «InsightsContentView фетчит все записи через @Query без предикатов; при росте объёма данных рассмотреть переход на `@Query(filter:)` по дате окна или прямой `ctx.fetch` с инвалидацией через `NotificationCenter`.»
- Этот раздел обновляется *по факту реализации*, не до.

### 12.4. Поведение `topStreaks` при наличии «вчерашних» стриков

**Контекст:** `HabitService.streak` возвращает `(value, isActive)` — `isActive == false` означает «вчера сделана, сегодня нет, value = вчерашний стрик». Такие стрики тоже попадают в топ-3, но цифра рисуется серым (`textGhost`).

**Открытый вопрос UX:** Если у пользователя в топ-3 окажется 3 неактивных стрика (все серые) — секция выглядит «потухшей». Возможно, лучше скрывать неактивные стрики целиком, оставляя только `isActive == true`.

**Решение для первой версии:** показываем все, включая неактивные (так в спеке HabitsView). Если по факту секция выглядит «потухшей» — переиграем в следующей итерации, флаг тривиальный (`if streak.isActive`).

---

## 13. Acceptance criteria

- [ ] Build succeeded, 0 warnings (`/build`).
- [ ] Lint clean (`/lint`).
- [ ] Format clean (`/format` без изменений).
- [ ] 21 тест `InsightsServiceTests` проходит.
- [ ] При первом запуске (пустая БД) экран показывает empty state «Нужно ещё немного данных».
- [ ] При наличии 3+ дней с данными показываются: заголовок, 3 метрики горизонтально, секция стриков (если есть `value > 0`), гистограмма настроения.
- [ ] Закрытие задачи на Today реактивно меняет цифру `% задач` (через `@Query`).
- [ ] Toggle привычки на Habits реактивно меняет `% привычек` и топ стриков.
- [ ] Cross-midnight: при возврате в приложение после полуночи окно сдвигается (`InsightsContentView` пересоздаётся через `.id(dateAnchor)`).
- [ ] Все View ≤ 150 строк.
- [ ] `#Preview` есть в каждом новом View.
