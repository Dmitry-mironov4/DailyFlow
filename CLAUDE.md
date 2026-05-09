# CLAUDE.md — DailyFlow

> Этот файл — твоя память между сессиями.
> Читай его в начале каждой сессии. Обновляй после значимых изменений.

---

## Проект

- **Название:** DailyFlow
- **Платформа:** iOS 26+, только iPhone (без iPad/Mac Catalyst)
- **Язык:** Swift 6, SwiftUI + SwiftData
- **Архитектура:** MVVM (ViewModels добавляются только там, где состояние/логика выходит за рамки одной View)
- **Бандл ID:** `com.dmitry.DailyFlow`
- **App Group:** `group.com.dmitry.dailyflow`
- **Локализация:** только русский (ru, development region)
- **Тема:** только тёмная (`UIUserInterfaceStyle = Dark` в pbxproj)
- **Xcode-проект:** `DailyFlow.xcodeproj` (Xcode 26, objectVersion 77, synchronized folder references). Деплоймент-таргет iOS 26.4, `SWIFT_VERSION = 6.0`, `TARGETED_DEVICE_FAMILY = "1"` (iPhone only), портретная ориентация.
- **Статус:** 🟢 Phase 1 завершена. Phase 2 завершена. Экраны «Сегодня» и «Привычки» полностью реализованы: все View, сервисы, модели, расширения, тесты. Build succeeded 0 warnings. Следующий шаг — экраны «Дневник», «Инсайты» (нужны спеки).

---

## Структура файлов

```
DailyFlow/                              # репозиторий
  CLAUDE.md
  .claude/                              # кастомный плагин: команды /build /lint /format /sim
    settings.json
    commands/
    skills/dailyflow-context/
  .swiftformat                          # форматирование (Swift 6, indent 4, maxwidth 120)
  .swiftlint.yml                        # линтинг
  docs/
    PROMPTS.md
    superpowers/
      specs/2026-05-07-today-screen-design.md
      plans/2026-05-07-today-screen.md

  DailyFlow.xcodeproj/                  # Xcode 26, objectVersion 77, synchronized folders

  DailyFlow/                            # source folder таргета DailyFlow (auto-discovered)
    Assets.xcassets/                    # AppIcon, AccentColor (Xcode-managed)
    App/
      DailyFlowApp.swift                # @main, точка входа, ModelContainer
      ContentView.swift                 # TabView × 4 вкладки
    Models/
      DailyTask.swift                   # @Model — задача дня (включая фокус)
      Habit.swift                       # @Model — привычка
      HabitLog.swift                    # @Model — отметка о выполнении привычки
      JournalEntry.swift                # @Model — запись настроения + текст
    Views/
      Today/
        TodayView.swift                 # обёртка: ScenePhase + dateAnchor
        TodayContentView.swift          # реальный UI с @Query (5 превью)
        FocusCardView.swift             # карточка фокус-задачи
        TaskRowView.swift               # строка задачи в списке + CheckboxView
        AddTaskBarView.swift            # ghost → inline TextField
        RolloverBannerView.swift        # плашка переноса вчерашних задач
      Habits/
        HabitsView.swift           # List + @Query + drag + ghost-кнопка добавления
        HabitCardView.swift        # карточка: toggle, streak, PixelGrid, contextMenu
        PixelGridView.swift        # 7 квадратов 28×28, последние 7 дней
        AddHabitSheet.swift        # sheet создания/редактирования привычки
      Journal/                          # экран «Дневник» (отдельный спек)
      Insights/                         # экран «Инсайты» (отдельный спек)
    Services/
      TaskService.swift                 # бизнес-логика задач (enum-namespace, stateless)
      HabitService.swift                # бизнес-логика привычек (enum-namespace, stateless)
      ObsidianService.swift             # экспорт .md через UIDocumentPickerViewController
      SettingsManager.swift             # UserDefaults в App Group
    Extensions/
      ColorExtensions.swift             # токены палитры (.bgPrimary, .accentTeal, …)
      ViewExtensions.swift              # модификаторы (.dfTitle, .dfBody, .dfCaption, .dfLabel, .dfCard, .dfAccentCard)
      Haptics.swift                     # enum Haptics { static func tap(_:) }
      Date+StartOfDay.swift             # var startOfDay: Date
      PreviewContainer.swift            # ModelContainer.preview(_ scenario:) + 5 сценариев
    Widgets/                            # отдельный таргет, добавляется позже
      DailyFlowWidgets.swift

  DailyFlowTests/                       # Swift Testing (не XCTest)
    Helpers/InMemoryContainer.swift     # TestContainer.make() → in-memory ModelContainer
    Models/DailyTaskTests.swift         # 3 теста инициализации
    Services/TaskServiceTests.swift     # 14 тестов TaskService
    Services/HabitServiceTests.swift    # 15 тестов HabitService

  DailyFlowUITests/                     # пустой UI-тест таргет, не используется
```

**Synchronized folder references:** Xcode 26 (`PBXFileSystemSynchronizedRootGroup`) автоматически подхватывает любой новый `.swift` файл в `DailyFlow/`, `DailyFlowTests/`, `DailyFlowUITests/`. Создавай файлы через Bash/Write — Xcode сам добавит их в нужный таргет.

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
| `bg.pixelInactive` | `#333333` | неактивные пиксели PixelGrid |

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
  isCompleted: Bool              # (было isDone, переименовано по спеку)
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
- [x] Экран «Сегодня» — полностью реализован, build ok, lint clean, 13 тестов (12 по спеку + 1 доп.)
- [x] Дизайн-токены и каркас: ContentView (иконки, таб-бар UITabBarAppearance), ViewExtensions (.dfLabel), верифицированы в симуляторе
- [x] Экран «Привычки» — полностью реализован, build ok, lint clean, 15 тестов HabitService
- [ ] Экран «Дневник» (нужен спек)
- [ ] Экран «Инсайты» (нужен спек)
- [ ] Экспорт в Obsidian (нужен спек)
- [ ] Виджеты (нужен спек)
- [ ] Локальные нотификации
- [ ] Бэкап JSON

---

## Известные проблемы

- **swipeActions + editMode:** В HabitsView используется `.environment(\.editMode, .constant(.active))` для drag-to-reorder. На iOS 26 нужно проверить, работает ли swipe-to-delete в этом режиме. Если нет — удалить swipeActions, оставить только contextMenu для удаления (или добавить NavigationStack + EditButton).
- **Color.bgPixelInactive:** Добавлен токен `#333333` для неактивных пикселей PixelGrid. Если дизайн-система расширится, возможно стоит переименовать в более семантическое имя.

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
