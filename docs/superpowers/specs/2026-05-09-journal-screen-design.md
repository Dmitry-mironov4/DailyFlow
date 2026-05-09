# Спецификация: Экран «Дневник» (DailyFlow)

**Дата:** 2026-05-09
**Статус:** утверждён, готов к написанию плана реализации
**Платформа:** iOS 26+, Swift 6, SwiftUI + SwiftData
**Связанные документы:** `DailyFlow/CLAUDE.md`, `docs/superpowers/specs/2026-05-07-today-screen-design.md`, `docs/superpowers/specs/2026-05-09-habits-screen-design.md`

---

## 1. Цель экрана

Третий из четырёх экранов TabView. Позволяет:
- Записать настроение дня по шкале 1–5.
- Записать свободный текст о дне (заметку/рефлексию).
- Делать это одним движением: lazy-создание записи, автосохранение, без явных кнопок «Сохранить».

Архитектурный паттерн совпадает с экранами «Сегодня» и «Привычки»: Pure SwiftUI + `@Query` + `JournalService`-namespace, без отдельного слоя ViewModel.

---

## 2. Журнал решений

| № | Вопрос | Решение |
|---|---|---|
| Q1 | Scope экрана | **Только сегодня.** Один экран = одна запись (текущий день). Никакой навигации по прошлым записям; история — на экране «Инсайты» и через экспорт в Obsidian. |
| Q2 | MoodPicker — что внутри тайла | **Цифры 1–5** в `.dfTitle`. SF Symbols не предоставляет последовательной шкалы из 5 «лиц настроения», поэтому в MVP-итерации — цифры. Возможный переход на собственные ассеты — отдельной задачей. |
| Q3 | Жизненный цикл `JournalEntry` | **Lazy / on first interaction.** При открытии экрана `@Query` ищет запись на сегодня; если её нет — UI показывает «пустое» состояние. Запись создаётся в базе только при первой реальной правке (выбор настроения или ввод первого символа). |
| Q4 | Хедер | **Дата `.dfCaption`** (как Today): `«СУББОТА, 9 МАЯ»`, `.textSecondary`, ALL CAPS, letter-spacing 0.5pt. |
| Q5a | Плейсхолдер TextEditor | «Что сегодня было?» |
| Q5b | Высота TextEditor | **Растягивается под весь оставшийся экран** под MoodPicker и хедером. |
| Q5c | Лимит символов | Без лимита. |
| Q6 | Кнопка «Сохранить в Obsidian» | **Отложена в отдельный спек экспорта (PROMPT 6).** На этом экране её нет. Поле `syncedToObsidian` модели не используется. |
| Q7 | Toast «Сохранено» | **Не показывается.** Автосохранение в SwiftData невидимое. |
| Q8a | Cross-midnight | **Не обрабатываем (YAGNI).** Дата фиксируется при открытии View и не меняется до закрытия. |
| Q8b | Закрытие клавиатуры | Кнопка «Готово» в `.toolbar(placement: .keyboard)` **+** тап по фону экрана. |
| Q8c | Повторный тап по выбранному mood-тайле | **Игнорируется** (no-op в сервисе, `updatedAt` не меняется). Снять выбор нельзя; для смены — тапнуть на другое значение. |
| Q9 | Если первой правкой был текст | Запись создаётся с `moodScore = 3` («нейтрально по умолчанию»). MoodPicker сразу показывает «3» как выбранный (ветка X). |
| A | Архитектурный подход | **Pure SwiftUI + `@Query` + `JournalService`-namespace.** Дочерние компоненты получают данные и колбэки от корневого View; `ModelContext` инкапсулирован в нём. |

---

## 3. Модели данных

Модель уже реализована и не требует изменений.

### `JournalEntry` (`@Model`)

```swift
@Model
final class JournalEntry {
    var id: UUID
    var date: Date              // ВСЕГДА startOfDay
    var moodScore: Int          // 1–5; см. инвариант ниже
    var text: String            // может быть пустым (если выбран только mood)
    var syncedToObsidian: Bool  // не используется на этом экране, остаётся для PROMPT 6
    var createdAt: Date
    var updatedAt: Date

    init(date: Date, moodScore: Int = 3, text: String = "")
}
```

**Инварианты:**
- На одну дату — не более одной `JournalEntry`. Гарантия: `JournalService.entryForToday(in:)` фильтрует по `#Predicate { $0.date == startOfDay }` и возвращает первую найденную; `getOrCreateToday` использует тот же поиск перед инсертом.
- `moodScore ∈ 1...5`. Дефолт `3` в `init` применяется только в момент lazy-создания записи через ввод текста; при создании через mood-тап `moodScore` сразу перезаписывается выбранным значением.
- `date` всегда `startOfDay` (нормализация в `init`).

---

## 4. Сервисный слой: `JournalService`

`enum`-namespace со статическими функциями. Принимает `ModelContext` явным параметром. Stateless (как `TaskService`/`HabitService`).

### 4.1. API

```swift
enum JournalService {
    /// Возвращает запись за сегодня или nil если её нет.
    /// Используется из мест, где @Query неудобен (тесты, экспорт).
    static func entryForToday(in ctx: ModelContext, now: Date = .now) -> JournalEntry?

    /// Возвращает существующую запись или создаёт новую с дефолтами и инсертит в контекст.
    /// Дефолты: moodScore = 3, text = "".
    @discardableResult
    static func getOrCreateToday(in ctx: ModelContext, now: Date = .now) -> JournalEntry

    /// Устанавливает moodScore.
    /// Если значение совпадает с текущим — no-op (updatedAt не меняется, см. Q8c).
    /// Если записи нет — создаёт через getOrCreateToday и сразу выставляет.
    /// precondition(1...5 ~= score) — защита в debug.
    static func setMood(_ score: Int, in ctx: ModelContext, now: Date = .now)

    /// Записывает text.
    /// Если запись отсутствует и text пустой — no-op (не плодим пустые записи).
    /// Если запись отсутствует и text не пустой — создаёт через getOrCreateToday и пишет text.
    /// Обновляет updatedAt только если значение реально изменилось.
    static func setText(_ text: String, in ctx: ModelContext, now: Date = .now)
}
```

### 4.2. Дизайн-решения

- **`now: Date = .now`** в каждой функции — для тестируемости (передаём фиксированную дату из тестов, проверяем `entry.date == now.startOfDay`).
- **Lazy-логика в одном месте.** View вызывает `setMood` / `setText`, не думая о существовании записи. Это инкапсулирует все сценарии «создать → присвоить» в сервисе.
- **No-op `setMood` при том же значении.** View просто шлёт «выбрано N» в обоих случаях; сервис разберётся. Это реализация инварианта Q8c на уровне сервиса.
- **`syncedToObsidian` не трогаем** — поле живёт в спеке экспорта (PROMPT 6).
- **Удаление пустых записей не предусмотрено.** Если пользователь добавил mood и стёр текст — запись остаётся (mood — данные). YAGNI; устраняет edge-кейсы «удалить запись с текстом».
- **`#Predicate` для поиска по дате.** `let target = Calendar.current.startOfDay(for: now); #Predicate<JournalEntry> { $0.date == target }`.

---

## 5. Структура файлов и UI

### 5.1. Состав файлов

```
DailyFlow/
  Models/
    JournalEntry.swift                   # уже существует, без изменений
  Services/
    JournalService.swift                 # NEW
  Views/Journal/
    JournalView.swift                    # обёртка экрана: хедер + контент
    MoodPickerView.swift                 # 5 тайлов с цифрами 1–5
    JournalEditorView.swift              # TextEditor + плейсхолдер + autosave
DailyFlowTests/
  Services/JournalServiceTests.swift     # ~15 тестов
```

Каждый View-файл ≤ 150 строк. Декомпозиция оправдана: `JournalEditorView` несёт debounce-логику и `@FocusState`; `MoodPickerView` — отдельный компонент с собственными превью.

### 5.2. `JournalView` (корневой)

```swift
struct JournalView: View {
    @Environment(\.modelContext) private var ctx
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
        .toolbar { keyboardDoneToolbar }
        .onTapGesture { dismissKeyboard() }
    }
}
```

- `@Query` фильтр инициализируется в `init()` с захваченной `today.startOfDay`. Cross-midnight НЕ обрабатываем (Q8a): дата фиксируется при создании View и держится до закрытия экрана.
- `entries.first` — единственная возможная запись на сегодня. Если её нет — `nil` (lazy).
- `dismissKeyboard()` — хелпер: `UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), ...)`.
- `keyboardDoneToolbar` — `ToolbarItemGroup(placement: .keyboard)` с одной кнопкой «Готово».

### 5.3. `MoodPickerView`

```swift
struct MoodPickerView: View {
    let selectedScore: Int?      // nil = ни один не выбран
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
```

**`MoodTile`:**
- Размер: `maxWidth: .infinity, height: 56pt` (5 тайлов поделят горизонталь поровну с учётом spacing 8 и horizontal padding 16).
- Скругление: 12pt.
- Невыбранный: фон `.bgCard`, цифра `.textSecondary`.
- Выбранный: фон `.accentPurple`, цифра `.textPrimary`.
- Цифра отображается стилем `.dfTitle` (21pt medium), по центру тайла.

### 5.4. `JournalEditorView`

```swift
struct JournalEditorView: View {
    let entry: JournalEntry?
    let onTextChange: (String) -> Void

    @State private var text: String = ""
    @State private var saveTask: Task<Void, Never>? = nil
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Что сегодня было?")
                    .dfBody()
                    .foregroundStyle(Color.textGhost)
                    .padding(.top, 8)
                    .padding(.leading, 4)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .focused($focused)
                .scrollContentBackground(.hidden)
                .background(Color.bgCard)
                .dfBody()
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            onTextChange(text)   // flush последнего ввода
        }
    }
}
```

**Решения:**
- **Плейсхолдер** — отдельный `Text` поверх `TextEditor`, скрывается когда `text.isEmpty == false`. SwiftUI `TextEditor` в iOS 26 не поддерживает нативный `prompt:` для многострочного режима.
- **Debounce 1.5с** — cancellable `Task` с `Task.sleep`. На каждое изменение текста предыдущая задача отменяется. Чисто Swift Concurrency, без Combine.
- **Mood — НЕ debounced.** Сохранение мгновенное, в `JournalView`.
- **`scrollContentBackground(.hidden) + background(.bgCard)`** — стандартный приём чтобы убрать дефолтный белый фон `TextEditor` и подставить наш.
- **`.frame(maxHeight: .infinity)`** — растягивается под весь оставшийся вертикальный спейс (Q5b).
- **`onDisappear`** — flush pending debounce (синхронный вызов `onTextChange`), чтобы не потерять последний ввод при закрытии экрана.
- **`ScenePhase` flush.** Ожидаемо: `JournalView` слушает `@Environment(\.scenePhase)` и при переходе в `.background` тоже принудительно вызывает `onTextChange` для дочернего редактора. Реализация: проброс через `onChange(of: scenePhase)` и shared closure.

### 5.5. Компоновка экрана

```
┌────────────────────────────────────┐
│  СУББОТА, 9 МАЯ      (.dfCaption)  │  ← top 12pt от safe area
│                                    │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐         │  ← MoodPicker, 56pt высота
│  │1 │ │2 │ │3 │ │4 │ │5 │         │     spacing 8pt, выбранный = purple
│  └──┘ └──┘ └──┘ └──┘ └──┘         │
│                                    │
│  ┌──────────────────────────────┐ │  ← TextEditor card
│  │ Что сегодня было?            │ │
│  │                              │ │
│  │ (растягивается до tab bar)   │ │
│  │                              │ │
│  └──────────────────────────────┘ │
│                                    │
│      [tab bar — Сегодня/...]      │
└────────────────────────────────────┘

paddings: horizontal 16, между блоками 16, top 12
```

---

## 6. Edge-кейсы и поведение

| Сценарий | Поведение |
|---|---|
| Открыли экран впервые сегодня | `@Query` возвращает `[]`. MoodPicker — никто не выбран, TextEditor показывает плейсхолдер. `JournalEntry` НЕ создаётся. |
| Тап по mood-тайлу первый раз | `JournalService.setMood(score, in: ctx)` → создаёт запись через `getOrCreateToday` → выставляет `moodScore = score` → `updatedAt = .now`. Хаптика `.light`. |
| Ввод первого символа текста | Через 1.5с debounce → `JournalService.setText(...)` → создаёт запись с `moodScore = 3` (Q9) → пишет text. MoodPicker сразу подсвечивает «3». |
| Тап по уже выбранному mood-тайлу | Хаптика срабатывает; `JournalService.setMood` вызывается, но внутри — no-op (тот же score). `updatedAt` НЕ меняется. |
| Стирание текста до пустого | Debounce → `JournalService.setText("", ...)`. Если запись есть — `entry.text = ""`, `updatedAt = .now`. Запись остаётся (в ней может быть mood). |
| Закрытие экрана с pending debounce | `onDisappear` → `saveTask?.cancel()`, синхронный `onTextChange(text)` — flush последнего ввода. |
| Уход в background | `ScenePhase` смена → принудительный flush pending debounce, как в `onDisappear`. |
| Пересечение полуночи с открытым экраном | Не обрабатываем (Q8a). Запись остаётся за дату, зафиксированную при открытии. |
| Удаление записи извне | `@Query` обновится → `entries.first == nil` → MoodPicker сбрасывается, текст очищается через `.onChange(of: entry?.text)`. На практике в MVP такого не случится. |
| Большой текст (> экрана) | Внутренний скролл `TextEditor`. Хедер и MoodPicker всегда видны сверху (не используем `ScrollView` для всего экрана). |
| Динамический тип `.medium`–`.xxxLarge` | MoodTile: цифра в `.dfTitle` масштабируется автоматически. Тайл 56pt — фиксированный. Хедер `.dfCaption` тоже масштабируется. TextEditor — стандартное поведение. |
| Дабл-тап / быстрые тапы по mood | Безопасно благодаря no-op на одинаковом значении. На разных значениях — переключение успевает обработаться. |

---

## 7. Превью

В `PreviewContainer.swift` уже есть `ModelContainer.preview(_ scenario:)` с пятью сценариями для Today/Habits. Добавим Journal-сценарии:

```swift
enum JournalScenario {
    case empty                  // нет записи за сегодня → MoodPicker пуст, плейсхолдер
    case moodOnly               // запись с moodScore = 4, text = ""
    case fullEntry              // moodScore = 5, text = "Сегодня прошёл день в потоке…"
    case longText               // text на ~2000 символов для проверки скролла внутри редактора
}
```

`#Preview` блоки:
- `JournalView` × 4 (по одному на каждый сценарий) с `.preferredColorScheme(.dark)`.
- `MoodPickerView` × 2: `selected = nil` и `selected = 3`.
- `JournalEditorView` × 2: пустой и заполненный.

---

## 8. Тесты — `JournalServiceTests.swift`

Используем `TestContainer.make()` (in-memory `ModelContainer`, уже есть в `Helpers/InMemoryContainer.swift`). Swift Testing.

| # | Тест | Проверяет |
|---|---|---|
| 1 | `entryForToday_returnsNil_whenNoEntry` | На пустой базе возвращает nil. |
| 2 | `entryForToday_returnsEntry_whenExistsForToday` | Создали запись на startOfDay(.now) → возвращается она. |
| 3 | `entryForToday_returnsNil_whenEntryIsForYesterday` | Запись на вчера не считается «сегодняшней». |
| 4 | `getOrCreateToday_createsWithDefaults_whenAbsent` | moodScore = 3, text = "", date = startOfDay(.now). |
| 5 | `getOrCreateToday_returnsExisting_andDoesNotDuplicate` | Второй вызов возвращает ту же запись; в базе одна. |
| 6 | `setMood_createsEntry_andSetsScore_whenAbsent` | После вызова на пустой базе появляется запись с указанным score. |
| 7 | `setMood_updatesScore_whenEntryExists` | Изменяет moodScore и updatedAt. |
| 8 | `setMood_isNoOp_whenSameScore` | updatedAt не меняется при том же значении (Q8c). |
| 9 | `setText_createsEntry_whenTextNonEmpty_andAbsent` | Запись появляется, moodScore = 3 (дефолт), text присвоен. |
| 10 | `setText_doesNotCreateEntry_whenTextEmpty_andAbsent` | На пустой базе вызов с "" не создаёт запись. |
| 11 | `setText_updatesText_whenEntryExists` | text и updatedAt обновляются; moodScore не трогается. |
| 12 | `setText_acceptsEmptyString_whenEntryExists` | Очистка текста разрешена; запись остаётся. |
| 13 | `entry_dateIsAlwaysStartOfDay` | После создания через сервис `entry.date == startOfDay`. |
| 14 | `setMood_acceptsBoundaryValues` | Принимает 1 и 5 без падений. |
| 15 | `setText_isNoOp_whenSameValue` | Повторный вызов с тем же текстом не меняет updatedAt. |

**Не покрывается тестами (намеренно):**
- View-логика debounce — валидируется вручную в превью/симуляторе.
- Хаптика, плейсхолдер, lifecycle `@FocusState`.
- Cross-midnight — заявлено как не поддерживаемое (Q8a).

---

## 9. Acceptance criteria

Готовность экрана = все пункты выполнены:

1. Экран «Дневник» открывается из TabView (третья вкладка) — заменяет текущий placeholder в `ContentView`.
2. Хедер показывает дату сегодня в формате `«СУББОТА, 9 МАЯ»` стилем `.dfCaption` (`textSecondary`, ALL CAPS, letter-spacing 0.5pt).
3. MoodPicker — 5 тайлов 56pt высоты со скруглением 12pt, цифры 1–5 в `.dfTitle`. Выбранный: фон `.accentPurple`, цифра `.textPrimary`. Невыбранный: фон `.bgCard`, цифра `.textSecondary`. Spacing 8pt. Тап = выбор + хаптика `.light`. Повторный тап по выбранному = no-op (`updatedAt` не меняется).
4. TextEditor растягивается под весь оставшийся экран. Пустой — плейсхолдер «Что сегодня было?» цветом `.textGhost`. Текст в `.dfBody` цветом `.textPrimary`. Фон карточки `.bgCard`, скругление 12pt.
5. Автосохранение текста — debounce 1.5с после последнего изменения. Автосохранение настроения — мгновенно при тапе. Toast не показывается.
6. При закрытии экрана / уходе в background pending debounce принудительно вызывается (текст не теряется).
7. Кнопка «Готово» в `.toolbar(placement: .keyboard)` закрывает клавиатуру. Тап по фону экрана (вне TextEditor) — тоже закрывает.
8. Lazy-создание `JournalEntry`: на пустой базе и без действий запись НЕ создаётся. Появляется при первом mood-тапе или первом непустом тексте.
9. Если первой правкой был текст — запись создаётся с `moodScore = 3`, MoodPicker сразу показывает «3» как выбранный.
10. Cross-midnight НЕ обрабатывается: дата фиксируется при открытии экрана и не меняется до закрытия.
11. Кнопка «Сохранить в Obsidian» отсутствует на экране — она часть отдельного спека экспорта (PROMPT 6). Поле `syncedToObsidian` не трогается.
12. В тёмной теме читаемо при динамическом типе `.medium`–`.xxxLarge`.
13. `swiftformat` и `swiftlint` проходят без warnings. `xcbeautify`-сборка чистая.
14. Все тесты `JournalServiceTests` проходят (15 штук). Существующие тесты Today/Habits не сломаны.
15. В `CLAUDE.md` обновлены секции «Статус», «Структура файлов» (добавлен `Views/Journal/`, `JournalService`), «Выполненные фичи» (отмечен Дневник).

---

## 10. Out of scope (для следующих спеков)

- **Экспорт в Obsidian** (`syncedToObsidian`, `.md` формат, `UIDocumentPickerViewController`) — PROMPT 6.
- **Графики настроения за период** — экран «Инсайты», отдельный спек.
- **Навигация по прошлым записям внутри Дневника** — намеренно вне scope (см. Q1).
- **Cross-midnight** — намеренно вне scope (Q8a).
- **Собственные иконки настроения вместо цифр** — возможная итерация, отдельная задача (Q2).
- **Редактирование записи за прошлый день** — вне scope; возможно через «Инсайты» в будущем.
- **Локальные нотификации с напоминанием записать запись** — отдельная фича.
