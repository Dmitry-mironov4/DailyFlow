# CLAUDE.md — DailyFlow

> Этот файл — твоя память между сессиями.
> Читай его в начале каждой сессии. Обновляй после значимых изменений.

---

## Проект

- **Название:** DailyFlow
- **Платформа:** iOS 26+, только iPhone (без iPad/Mac Catalyst)
- **Язык:** Swift 6, SwiftUI + SwiftData
- **Архитектура:** MVVM (ViewModels добавляются только там, где состояние/логика выходит за рамки одной View)
- **Бандл ID:** `com.dmitry.dailyflow` (предполагаемый)
- **App Group:** `group.com.dmitry.dailyflow`
- **Локализация:** только русский (ru)
- **Тема:** только тёмная, без auto/light
- **Статус:** 🟡 Скаффолдинг завершён, дизайн-токены и кастомный `.claude/` плагин настроены. Спек экрана «Сегодня» утверждён ([`docs/superpowers/specs/2026-05-07-today-screen-design.md`](./docs/superpowers/specs/2026-05-07-today-screen-design.md)). Следующий шаг — `superpowers:writing-plans` в новой сессии.

---

## Структура файлов

```
DailyFlow/
  CLAUDE.md
  .claude/                      # кастомный плагин: команды /build /lint /format /sim
    settings.json
    commands/
    skills/dailyflow-context/
  .swiftformat                  # форматирование (Swift 6, indent 4, maxwidth 120)
  .swiftlint.yml                # линтинг
  docs/
    PROMPTS.md                  # шаблоны промтов для отдельных сессий
    superpowers/
      specs/
        2026-05-07-today-screen-design.md
  App/
    DailyFlowApp.swift          # @main, точка входа, SwiftData container
    ContentView.swift           # TabView с 4 вкладками
  Models/
    DailyTask.swift             # @Model — задача дня (включая фокус)
    Habit.swift                 # @Model — привычка
    HabitLog.swift              # @Model — отметка о выполнении привычки
    JournalEntry.swift          # @Model — запись настроения + текст
  Views/
    Today/
      TodayView.swift           # обёртка: ScenePhase + dateAnchor
      TodayContentView.swift    # реальный UI с @Query (см. spec)
      FocusCardView.swift       # карточка фокус-задачи
      TaskRowView.swift         # строка задачи в списке
      AddTaskBarView.swift      # ghost → inline TextField
      RolloverBannerView.swift  # плашка переноса вчерашних задач
    Habits/
      HabitsView.swift          # экран «Привычки»
      HabitCardView.swift       # карточка одной привычки
      PixelGridView.swift       # 7-дневная сетка пикселей
    Journal/
      JournalView.swift         # экран «Дневник»
      MoodPickerView.swift      # выбор настроения 1–5
    Insights/
      InsightsView.swift        # экран «Инсайты»
      WeekStatView.swift        # карточка недельной статистики
  Services/
    TaskService.swift           # бизнес-логика задач: add/toggle/setFocus/rollover
    ObsidianService.swift       # экспорт .md через UIDocumentPickerViewController
    SettingsManager.swift       # пользовательские настройки (UserDefaults в App Group)
  Widgets/
    DailyFlowWidgets.swift      # WidgetKit: фокус-задача + pixel grid
  Extensions/
    ColorExtensions.swift       # токены палитры (.bgPrimary, .accentTeal, …)
    ViewExtensions.swift        # модификаторы (.dfTitle, .dfCard, .dfAccentCard)
    Haptics.swift               # обёртка над UIImpactFeedbackGenerator
    Date+StartOfDay.swift       # var startOfDay: Date
    PreviewContainer.swift      # in-memory ModelContainer для #Preview-сценариев

DailyFlowTests/                 # таргет тестов (Swift Testing, не XCTest)
  Helpers/
    InMemoryContainer.swift
  Services/
    TaskServiceTests.swift
  Models/
    DailyTaskTests.swift
```

**Правило:** каждый View-файл ≤ 150 строк. Если становится длиннее — выноси компоненты.

---

## Дизайн-система

### Цветовая палитра

| Токен | HEX | Использование |
|---|---|---|
| `bg.primary` | `#0D0D0D` | фон экрана |
| `bg.card` | `#1A1A1A` | фон карточки |
| `accent.teal` | `#2DD4A0` | задачи, Obsidian, кнопка экспорта |
| `accent.amber` | `#F0A23B` | привычки, индикаторы стриков |
| `accent.purple` | `#9B8AE8` | настроение, графики статистики |
| `text.primary` | `#F2F2F2` | основной текст, заголовки |
| `text.secondary` | `#888888` | метаданные, неактивные элементы |
| `text.ghost` | `#666666` | плейсхолдеры, ghost-кнопки (заменён с `#444444`) |

**Запрещено:** градиенты, тени, размытие, полупрозрачные оверлеи, декоративные иконки. Только плоские цвета.

### Типографика — SF Pro (системный)

| Роль | Размер | Вес | Доп. |
|---|---|---|---|
| Title | 21pt | `.medium` | — |
| Body | 13pt | `.regular` | — |
| Caption | 10pt | `.regular` | letter-spacing 0.5pt, ALL CAPS |

**Динамический тип:** да, минимум поддержать `.medium`–`.xxxLarge`.

### Раскладка
- Безопасные отступы карточки: 16pt по горизонтали, 14pt вертикально
- Скругление карточек: 12pt
- Расстояние между карточками: 12pt
- Глобальный фон экрана не имеет вертикального паддинга — карточки доходят до краёв с горизонтальным отступом 16pt

---

## Архитектурные решения

- **Pure SwiftUI + `@Query` + Service-namespace** — никаких `@Observable ViewModel`. UI-only state — в `@State`. Бизнес-логика — в `enum`-namespace со статическими функциями, принимающими `ModelContext` (`TaskService`, далее аналогично `HabitService`, `JournalService`).
- **SwiftData** для всего локального хранения (`@Model` на каждой сущности).
- **iCloud Drive** для экспорта `.md` через `UIDocumentPickerViewController` (НЕ ubiquity container напрямую).
- **WidgetKit** для виджетов home screen.
- **App Groups** (`group.com.dmitry.dailyflow`) для шаринга SwiftData store с виджетом.
- **Swift Charts** для графиков на экране «Инсайты» (нативный фреймворк, не сторонняя зависимость).
- **UNUserNotificationCenter** для локальных нотификаций привычек (без серверов).
- **Никаких сторонних SPM/CocoaPods зависимостей** — только Apple-фреймворки.
- **Cross-midnight через `.id(dateAnchor)`** — двухслойный View (обёртка + Content), переинициализирующийся при пересечении полуночи (см. spec Today, раздел 6).
- **Тесты:** Swift Testing (нативный для iOS 26+), in-memory `ModelContainer`. Покрывается логика сервисов, не View.
- **Бэкап:** еженедельный авто-экспорт всей SwiftData-базы в JSON в каталог Obsidian (резерв на случай миграции/повреждения).

### Карта Models

```
DailyTask                        # утверждено в spec Today, раздел 3.1
  id: UUID
  title: String
  isFocus: Bool                  # инвариант: max 1 true на одну date
  isCompleted: Bool              # переименовано из isDone
  date: Date                     # ВСЕГДА startOfDay
  createdAt: Date                # для сортировки ASC
  completedAt: Date?             # для статистики и markdown-экспорта

Habit                            # детали уточняются в спеке экрана Привычки
  id: UUID
  name: String
  colorHex: String               # "2DD4A0" / "F0A23B" / "9B8AE8"
  sortOrder: Int
  createdAt: Date
  logs: [HabitLog]               # @Relationship(deleteRule: .cascade)

HabitLog
  id: UUID
  date: Date                     # startOfDay
  completedAt: Date
  habit: Habit?                  # @Relationship inverse

JournalEntry                     # детали уточняются в спеке экрана Дневник
  id: UUID
  date: Date                     # startOfDay, одна запись на день
  moodScore: Int                 # 1–5
  text: String
  syncedToObsidian: Bool
  createdAt: Date
  updatedAt: Date
```

---

## Выполненные фичи

- [x] Скаффолдинг проекта (структура папок, пустые файлы)
- [x] Кастомный `.claude/` плагин (`/build /lint /format /sim` + skill `dailyflow-context`)
- [x] CLI-инструменты: swiftformat, swiftlint, xcbeautify
- [x] Спецификация экрана «Сегодня» ([2026-05-07-today-screen-design.md](./docs/superpowers/specs/2026-05-07-today-screen-design.md))
- [ ] Экран «Сегодня» (план реализации — следующий шаг)
- [ ] Экран «Привычки» (нужен спек)
- [ ] Экран «Дневник» (нужен спек)
- [ ] Экран «Инсайты» (нужен спек)
- [ ] Экспорт в Obsidian (нужен спек)
- [ ] Виджеты (нужен спек)
- [ ] Локальные нотификации
- [ ] Бэкап JSON

---

## Известные проблемы

_Пока пусто._

---

## Инструкции для Claude Code

1. **Всегда читай этот файл в начале сессии** перед любыми действиями с кодом.
2. **Обновляй разделы «Статус» и «Выполненные фичи»** после каждой завершённой фичи.
3. **Строго соблюдай дизайн-систему** — никаких отклонений от палитры, типографики, скруглений. Если требуется новый токен — сначала добавь его сюда.
4. **Используй `@Model` (SwiftData)** для всех сохраняемых данных.
5. **Каждый View-файл ≤ 150 строк.** Если ближе к лимиту — декомпозируй.
6. **`#Preview` обязателен в каждом View** — с реалистичными моковыми данными и тёмной темой.
7. **Отвечай на русском.**
8. **Перед новой фичей** — запускай скилл `superpowers:brainstorming`.
9. **Перед реализацией** — пиши план через `superpowers:writing-plans`.
10. **Перед «готово»** — `superpowers:verification-before-completion` (билд + лайфциклы + превью).
