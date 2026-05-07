# DailyFlow — Claude Code Prompts

Личный ежедневник с трекером привычек и интеграцией Obsidian.
Используй промты последовательно. Каждый — отдельная сессия Claude Code.

> **Источник истины:** [`DailyFlow/CLAUDE.md`](../CLAUDE.md) и [`DailyFlow/docs/superpowers/specs/`](./superpowers/specs/).
> Промты ниже — **точки входа в сессию**, не самостоятельные спецификации. Любые детали реализации Claude должен брать из spec-файлов и CLAUDE.md, а не из тела промта.

---

## Opus vs Sonnet — когда что использовать (Pro подписка)

У Pro лимит токенов ограничен. Используй Opus точечно, Sonnet — для рутины.

| Задача | Модель | Почему |
|--------|--------|--------|
| Брейнсторм фичи / спецификация | **Opus** | Архитектурные решения, поиск edge cases |
| Написание плана реализации (`writing-plans`) | **Opus** | Декомпозиция, порядок зависимостей |
| Реализация по уже готовому спеку и плану | **Sonnet** | «Сделай как написано» — Sonnet справится |
| Дебаг нетривиальной ошибки | **Opus** | Сложный анализ, гипотезы |
| Мелкий рефакторинг, переименования, комментарии | **Sonnet** | Не тратить Opus |
| Добавить один View-компонент по существующему паттерну | **Sonnet** | Шаблонная задача |
| Написать `#Preview` | **Sonnet** | Механически |
| Ревью кода | **Opus** | Нужен опыт и контекст |

**Правило:** «сделай как в спеке» → Sonnet. «Прими решение / распутай проблему» → Opus.

---

## Лог прогресса

| Этап | Статус | Артефакт |
|---|---|---|
| Стартовый промт | ✅ выполнен | разговор сохранён, решения в CLAUDE.md |
| ПРОМТ 0 (CLAUDE.md + скаффолдинг) | ✅ выполнен | `DailyFlow/CLAUDE.md`, дерево файлов, `.claude/` плагин |
| Установка инструментов (swiftformat, swiftlint, xcbeautify) | ✅ выполнен | `brew install …`, конфиги `.swiftformat`, `.swiftlint.yml` |
| Брейнсторм экрана «Сегодня» | ✅ выполнен | `docs/superpowers/specs/2026-05-07-today-screen-design.md` |
| Writing-plans для экрана «Сегодня» | ⏳ следующая сессия | будет в `docs/superpowers/plans/…` |
| ПРОМТ 1 (модели) | частично — DailyTask по спеку, остальные модели TBD | — |
| ПРОМТ 2–9 | ⏳ ждут | — |

---

## Как использовать промты ниже

Каждый промт — это **минимальная точка входа** для отдельной сессии Claude Code. Тело промта НЕ содержит детали реализации — только указание, какой spec / какой раздел CLAUDE.md прочитать.

Все детали (модель данных, API сервиса, структура View, edge cases, тесты, анимации, хаптика) живут в spec-файлах в `docs/superpowers/specs/`. Если в spec-файле чего-то нет — это пробел спецификации, его надо закрыть брейнстормом, а не угадыванием в коде.

---

## Стартовый промт ✅ выполнен

Использовался для первого открытия диалога с Claude. Все решения зафиксированы в `CLAUDE.md` и в брейнстормах. Оставляю шаблон ниже на случай поднятия аналогичного проекта.

```
Привет! Я хочу создать iOS-приложение на Swift/SwiftUI.
Пожалуйста, всегда отвечай мне на русском языке.

[краткое описание проекта]

Прежде чем писать код, ответь:
1. Какие MCP-серверы / плагины / CLI-инструменты ты рекомендуешь?
2. Какие skills стоит включить?
3. Что бы ты изменил в описании перед стартом?

После ответов я напишу "Начинаем".
```

---

## ПРОМТ 0 — CLAUDE.md и скаффолдинг ✅ выполнен

Артефакты:
- `DailyFlow/CLAUDE.md`
- Структура папок `App/Models/Views/Services/Widgets/Extensions`
- Кастомный `.claude/` плагин: `commands/build|lint|format|sim`, `skills/dailyflow-context`
- `.swiftformat`, `.swiftlint.yml`, `.claude/settings.json`

---

## ПРОМТ 1 — SwiftData модели

> Модель: **Opus** для `Habit` / `HabitLog` / `JournalEntry`.
> `DailyTask` — реализуется в составе спека «Сегодня» (Sonnet).

```
Прочитай:
- DailyFlow/CLAUDE.md
- DailyFlow/docs/superpowers/specs/2026-05-07-today-screen-design.md (для DailyTask)

Создай SwiftData модели:

1. DailyTask — строго по spec'у Today (раздел 3.1). isCompleted (НЕ isDone),
   completedAt: Date?, без sortOrder. Все date нормализуются через startOfDay в init.

2. Habit:
   - id: UUID, name: String, colorHex: String ("2DD4A0", "F0A23B", "9B8AE8")
   - createdAt: Date
   - @Relationship(deleteRule: .cascade) var logs: [HabitLog]
   Computed:
   - currentStreak: Int — подряд идущих дней с логами назад от сегодня
   - isCompletedToday: Bool

3. HabitLog:
   - id: UUID, date: Date (startOfDay), completedAt: Date
   - habit: Habit?

4. JournalEntry:
   - id: UUID, date: Date (startOfDay)
   - moodScore: Int (1–5), text: String
   - syncedToObsidian: Bool
   - createdAt: Date, updatedAt: Date

Helper-расширения:
- Extensions/Date+StartOfDay.swift (см. спек Today, раздел 17.3)
- Extensions/ColorExtensions.swift (см. спек Today, раздел 17.1) —
  токены палитры + init(hex:) для Color (на случай Habit.colorHex.asColor)

Добавь #Preview в каждый файл модели через ModelContainer(isStoredInMemoryOnly: true).

Обнови CLAUDE.md: отметь модели как выполненные, синхронизируй раздел «Карта Models».
```

---

## ПРОМТ 2 — Навигация и дизайн-токены

> Модель: **Sonnet** — механика по спеку.

```
Прочитай:
- DailyFlow/CLAUDE.md (раздел «Дизайн-система»)
- DailyFlow/docs/superpowers/specs/2026-05-07-today-screen-design.md (раздел 17)

FILE: App/DailyFlowApp.swift
ModelContainer со всеми четырьмя моделями (DailyTask, Habit, HabitLog, JournalEntry).

FILE: App/ContentView.swift
TabView с четырьмя вкладками:
  1. Сегодня  — SF Symbol "calendar"
  2. Привычки — SF Symbol "square.grid.2x2"
  3. Дневник  — SF Symbol "note.text"
  4. Инсайты  — SF Symbol "chart.bar"

Стилизация таб-бара (используй Color-токены из ColorExtensions):
  - Фон: .bgPrimary (#0D0D0D)
  - Активная иконка: .textPrimary (#F2F2F2)
  - Неактивная: .textGhost (#666666)  ← ОБНОВЛЕНО (раньше было #444444)
  - .toolbarBackground(.hidden, for: .tabBar)

На месте «Сегодня» — TodayView (заглушка из следующего промта).
Остальные три вкладки — Text("Скоро") в .textGhost.

FILE: Extensions/ColorExtensions.swift
Реализовано в ПРОМТ 1.

FILE: Extensions/ViewExtensions.swift
Модификаторы по spec'у Today, раздел 17.2:
  - .dfTitle()      — 21pt .medium, .textPrimary
  - .dfBody()       — 13pt .regular, .textPrimary
  - .dfCaption()    — 10pt, tracking 0.5, uppercase, .textGhost   ← ОБНОВЛЕНО
                      (раньше: 9pt, tracking 1, #444444)
  - .dfLabel()      — 11pt, .textSecondary
  - .dfCard()       — bg .bgCard, cornerRadius 12, padding .horizontal 16 / .vertical 14
                      (раньше padding 13/13 — заменено)
  - .dfAccentCard(color:) — color.opacity(0.08) фон, левый бордер 3pt, cornerRadius 12,
                            padding 16/14

FILE: Extensions/Haptics.swift
  enum Haptics { static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle) }

Запусти `/build` — должно скомпилироваться. Открой симулятор `/sim` — таб-бар должен
быть тёмным, без подложки, с серыми неактивными иконками.

Обнови CLAUDE.md: отметь дизайн-токены и каркас как выполненные.
```

---

## ПРОМТ 3 — Экран «Сегодня»

> Модель: **Sonnet** — реализация по детальному спеку.

```
Прочитай:
- DailyFlow/CLAUDE.md
- DailyFlow/docs/superpowers/specs/2026-05-07-today-screen-design.md (целиком)

Реализуй экран «Сегодня» строго по спеку. Не отступай от него.
Если найдёшь противоречие в спеке — НЕ угадывай, спроси.

Файлы (в порядке зависимостей):
1. Models/DailyTask.swift                      ← если ещё не создан
2. Services/TaskService.swift                  ← раздел 4 спека
3. Views/Today/TodayView.swift                 ← раздел 6.1
4. Views/Today/TodayContentView.swift          ← раздел 6.2 + 7
5. Views/Today/FocusCardView.swift             ← раздел 8.2
6. Views/Today/TaskRowView.swift               ← раздел 8.3
7. Views/Today/AddTaskBarView.swift            ← раздел 8.4
8. Views/Today/RolloverBannerView.swift        ← раздел 8.5
9. Extensions/PreviewContainer.swift           ← для #Preview сценариев

Тесты (раздел 14 спека):
- DailyFlowTests/Helpers/InMemoryContainer.swift
- DailyFlowTests/Services/TaskServiceTests.swift
- DailyFlowTests/Models/DailyTaskTests.swift

После реализации:
- `/lint` — должно быть чисто
- `/build` — успех
- запусти тесты Cmd+U в Xcode
- проверь все 5 #Preview визуально

Обнови CLAUDE.md:
  - Раздел «Структура файлов» (см. раздел 16 спека)
  - Раздел «Карта Models» (isCompleted, completedAt)
  - Раздел «Выполненные фичи»: [x] Экран «Сегодня»
  - Статус
```

---

## ПРОМТ 4 — Экран «Привычки»

> Модель: **Sonnet** — после написания спека этого экрана (Opus).

⚠️ **Перед этим промтом нужен брейнсторм + spec для экрана «Привычки»** (`docs/superpowers/specs/YYYY-MM-DD-habits-screen-design.md`). Без спека не пастить.

Шаблон промта после готового спека:
```
Прочитай:
- DailyFlow/CLAUDE.md
- DailyFlow/docs/superpowers/specs/<habits-spec-file>.md

Реализуй экран «Привычки» строго по спеку. Не отступай от него.
Если найдёшь противоречие — спроси, не угадывай.

После реализации: /lint, /build, проверь #Preview, обнови CLAUDE.md.
```

Конкретные элементы экрана (для брейнсторма):
- HabitsView (список карточек, ghost-кнопка добавления)
- HabitCardView (.dfCard()): название, текущий стрик, PixelGridView
- PixelGridView: 7 квадратов 28×28, spacing 4, последние 7 дней
- Sheet добавления: TextField + 3 кнопки выбора цвета (teal/amber/purple)
- Свайп удаления (cascade удаляет логи)
- Хаптика: .medium на toggle, .light на uncheck, .heavy на удаление

---

## ПРОМТ 5 — Экран «Дневник»

> Модель: **Sonnet** после Opus-брейнсторма.

⚠️ Сначала spec: `docs/superpowers/specs/YYYY-MM-DD-journal-screen-design.md`.

Конкретные элементы (для брейнсторма):
- JournalView: хедер, MoodPicker, TextEditor с placeholder, кнопка «Сохранить в Obsidian»
- MoodPickerView: 5 тайлов 1–5, выбранный — фон .accentPurple
- Автосохранение: debounce 1.5с после изменения текста, моментально на смене настроения
- Toast «Сохранено» 1.5с
- Хаптика: .light на выборе настроения

---

## ПРОМТ 6 — Экран «Инсайты»

> Модель: **Sonnet** после Opus-брейнсторма.

⚠️ Сначала spec. Архитектура та же — Pure SwiftUI + `@Query`, **никаких ViewModel**
(в первоначальной версии этого файла предлагался `InsightsViewModel` — отвергнуто:
противоречит общему архитектурному решению).

Конкретные элементы (для брейнсторма):
- WeekStatView: лейбл + большое число + прогресс-бар + подпись. Использовать Swift Charts
  для гистограммы настроения (нативный фреймворк, не сторонняя зависимость).
- 3 метрики-карточки: задачи %, привычки %, среднее настроение
- Секция «ЛУЧШИЕ СТРИКИ»
- Секция «НАСТРОЕНИЕ — последние 7 дней» — мини-гистограмма через Swift Charts
- Empty state при <3 дней данных

---

## ПРОМТ 7 — Интеграция с Obsidian

> Модель: **Opus** — нетривиальная логика.

⚠️ Сначала spec: `docs/superpowers/specs/YYYY-MM-DD-obsidian-export-design.md`.

**Важно — изменено относительно первой версии этого файла:**
Используем **`UIDocumentPickerViewController`** для выбора Obsidian-vault'а пользователем.
НЕ прямую запись в `iCloud~md~obsidian/Documents/...` — этот путь хрупкий и зависит от
деталей iCloud Drive layout. DocumentPicker:
- безопаснее (пользователь сам даёт доступ),
- работает независимо от расположения vault'а (iCloud / Dropbox / локально),
- стандартный iOS-паттерн.

Для брейнсторма:
- Структура `ObsidianService` (поиск vault, сохранение .md)
- Формат markdown-файла YYYY-MM-DD.md (frontmatter + секции Задачи / Привычки / Настроение / Запись)
- Перезапись существующего файла того же дня
- Обработка ошибок: iCloud недоступен, нет прав на запись, vault не выбран
- `SettingsManager` (`@Observable`, UserDefaults) — selectedVaultBookmark (security-scoped),
  obsidianFolder
- Кнопка «Сохранить в Obsidian» в JournalView подключается к этому сервису

---

## ПРОМТ 8 — Виджеты

> Модель: **Opus** — App Groups / WidgetKit нюансы.

⚠️ Сначала spec.

**App Group ID — зафиксирован: `group.com.dmitry.dailyflow`** (раньше был placeholder).

Для брейнсторма:
- SharedDataManager: чтение/запись JSON в App Group container, тип SharedDayData
- writeSharedData() вызывается на каждое изменение задач/привычек
- 3 виджета: SmallHabits (2×2), SmallStreak (2×2), MediumTasks (4×2)
- Timeline policy: 30 минут + invalidate при .scenePhase == .active в основном app
- URL scheme: dailyflow://today, dailyflow://habits — обработка в DailyFlowApp.swift

⚠️ **Не тестировать на iPhone SE** (раньше было в чеклисте) — SE 1-3 gen не получит iOS 26.
Тестируй на iPhone 16 Pro / 17 Pro Max.

---

## ПРОМТ 9 — Финальная полировка

> Модель: **Sonnet**.

```
Прочитай CLAUDE.md.

УВЕДОМЛЕНИЯ:
  - Запросить разрешение при первом запуске
  - 3 ежедневных уведомления, время в Settings:
    09:00 "Доброе утро! Что сегодня важно?"
    20:00 "Не забудь записать день"
    21:00 "Отметь привычки"
  UNUserNotificationCenter, время в UserDefaults через App Group.

ПРОВЕРЬ ХАПТИКИ (свод по спекам):
  - Добавить задачу: .light
  - Toggle complete: .medium
  - Toggle привычки (set): .medium
  - Toggle привычки (unset): .light
  - Set/clear focus: .medium
  - Edit save: .light
  - Delete (свайп или меню): .heavy
  - Mood pick: .light
  - Rollover «Перенести»: .light
  - Rollover «Очистить»: .medium
  - Успешный экспорт в Obsidian: UINotificationFeedbackGenerator(.success)
  - Ошибка: UINotificationFeedbackGenerator(.error)

ПРОВЕРЬ АНИМАЦИИ (свод):
  - Чекбокс задачи: .easeInOut(0.15) opacity + strikethrough
  - Pixel-квадрат сегодня: .scaleEffect 1.0 → 1.05 → 1.0 spring при появлении
  - Прогресс-бары Insights: .easeOut(0.6) на appear
  - Появление/скрытие FocusCard, RolloverBanner: .transition(.opacity + .move(.top))

EMPTY STATES:
  - Сегодня: AddBar сам по себе — без отдельного empty-state-сообщения (по спеку Today)
  - Привычки: «Начни с одной простой привычки» — 13pt .textGhost, центр, отступ 40pt сверху
  - Инсайты: «Данные появятся после нескольких дней» — тот же стиль
  Дневник пустого состояния не имеет (всегда создаётся запись на сегодня)

SAFE AREAS:
  - .ignoresSafeArea(.keyboard, edges: .bottom) на ScrollView каждой вкладки
  - Bottom-padding 100pt в ScrollView'ах под таб-бар

ФИНАЛЬНАЯ ПРОВЕРКА:
  1. Симулятор iPhone 16 Pro — все экраны
  2. Симулятор iPhone 17 Pro Max — ничего не обрезается
  3. Все #Preview работают
  4. Создай Strings.swift со всеми UI-текстами (даже одной локалью —
     централизация копирайта на будущее)

ОБНОВИ CLAUDE.md:
  - Версия v1.0
  - Секция «Как запустить»
  - Известные проблемы / идеи v2.0
```

---

## Промт для дебага

> Модель: **Opus**.

```
Прочитай CLAUDE.md и spec того экрана/модуля где проблема
(если применимо).

Проблема: [что происходит]
Шаги воспроизведения: [как воспроизвести]
Ожидаемое поведение: [что должно быть]
Связанный код: [вставь]
Сообщение об ошибке: [если есть]

Перед предложением фикса — используй скилл systematic-debugging:
сформулируй гипотезу, изолируй проблему, проверь.
Не «попробуй это», а «причина в X, потому что Y».
```

---

## Промт для добавления компонента

> Модель: **Sonnet** — если паттерн уже есть в codebase.

```
Прочитай CLAUDE.md.

Добавь [название]:
[что делает]

Соблюдай дизайн-систему. Используй существующие .dfXxx модификаторы и Color-токены.
Добавь #Preview с реалистичными моковыми данными.
Не плоди новые файлы, если можно расширить существующий.
```

---

## Полезные команды

```bash
# Запустить Claude Code в проекте
cd ~/Developer/DailyFlow && claude

# Команды плагина DailyFlow (внутри сессии Claude Code)
/build      # xcodebuild + xcbeautify
/lint       # swiftformat --lint + swiftlint
/format     # swiftformat (с подтверждением)
/sim        # iPhone 16 Pro симулятор

# Стандартные слэш-команды Claude Code
/help       # список команд
/review     # ревью текущего файла
/clear      # сбросить контекст
```

---

## Cowork (это приложение) — что использовать параллельно

| Задача | Skill |
|---|---|
| Ревью скриншота из симулятора | `design:design-critique` |
| Аудит доступности | `design:accessibility-review` |
| Тексты кнопок и empty states | `design:ux-copy` |
| Спец для нового экрана → Claude Code | `superpowers:brainstorming` → `writing-plans` |
| Трекать задачи разработки | `productivity:task-management` |
| Финальное ревью большой ветки | `/ultrareview` (внутри Claude Code) |

**Рабочий сетап:** Claude Code в терминале / IDE + Xcode + Simulator. Cowork (это приложение) — для брейнсторма, ревью скриншотов, и любой работы где нужен Opus с визуальным контекстом.
