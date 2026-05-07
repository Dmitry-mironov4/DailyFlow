# Today Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Реализовать экран «Сегодня» (DailyFlow) — фокус-карта дня, список задач, quick-capture, rollover-банер; задать архитектурный паттерн Pure SwiftUI + `@Query` + Service-namespace для остальных экранов.

**Architecture:** Pure SwiftUI без `@Observable ViewModel`. Каждый View — `@Query` + `@State` UI-state. Бизнес-логика — `enum TaskService` со статическими функциями, принимающими `ModelContext`. Cross-midnight через двухслойный View (`TodayView` — обёртка с `dateAnchor`, `TodayContentView` — реальный UI с `.id(dateAnchor)`). Тесты — нативный Swift Testing (iOS 26+) на in-memory `ModelContainer`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (`@Model`, `@Query`, `#Predicate`), Swift Testing, нативные UIKit-хелперы (`UIImpactFeedbackGenerator`). Никаких сторонних SPM-зависимостей.

**Спецификация:** [docs/superpowers/specs/2026-05-07-today-screen-design.md](../specs/2026-05-07-today-screen-design.md).

---

## Команды

- Сборка: `/build` (= `xcodebuild -project DailyFlow.xcodeproj -scheme DailyFlow -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build | xcbeautify`).
- Линт: `/lint` (= `swiftformat --lint .` + `swiftlint`).
- Формат: `/format`.
- Тесты: `xcodebuild test -project DailyFlow.xcodeproj -scheme DailyFlow -destination 'platform=iOS Simulator,name=iPhone 16 Pro' | xcbeautify` (или Cmd+U в Xcode).

Имитировать сборку или генерировать `project.pbxproj` руками **запрещено** — Xcode-проект создаётся в Phase 0 (см. ниже).

---

## Карта файлов

| Путь | Создать / Изменить | Ответственность |
|---|---|---|
| `DailyFlow/Extensions/ColorExtensions.swift` | Создать | Цветовые токены + `Color(hex:)` |
| `DailyFlow/Extensions/ViewExtensions.swift` | Создать | Модификаторы `.dfTitle/.dfBody/.dfCaption/.dfCard/.dfAccentCard` |
| `DailyFlow/Extensions/Date+StartOfDay.swift` | Создать | `Date.startOfDay` |
| `DailyFlow/Extensions/Haptics.swift` | Создать | Обёртка `Haptics.tap(_:)` |
| `DailyFlow/Extensions/PreviewContainer.swift` | Создать | `ModelContainer.preview(_:)` для `#Preview` |
| `DailyFlow/Models/DailyTask.swift` | Заменить (сейчас стаб) | `@Model final class DailyTask` |
| `DailyFlow/Models/Habit.swift` | Заменить (сейчас стаб) | Минимальный `@Model` (для schema) |
| `DailyFlow/Models/HabitLog.swift` | Заменить (сейчас стаб) | Минимальный `@Model` |
| `DailyFlow/Models/JournalEntry.swift` | Заменить (сейчас стаб) | Минимальный `@Model` |
| `DailyFlow/Services/TaskService.swift` | Создать | `enum TaskService` — add/toggle/setFocus/.../rollover |
| `DailyFlow/App/DailyFlowApp.swift` | Заменить (сейчас стаб) | `@main`, `ModelContainer` со всеми 4 моделями |
| `DailyFlow/App/ContentView.swift` | Заменить (сейчас стаб) | `TabView` × 4 (Сегодня/Привычки/Дневник/Инсайты) |
| `DailyFlow/Views/Today/TodayView.swift` | Заменить (сейчас стаб) | Обёртка `ScenePhase` + `dateAnchor` |
| `DailyFlow/Views/Today/TodayContentView.swift` | Создать | Главный UI с `@Query` |
| `DailyFlow/Views/Today/FocusCardView.swift` | Заменить (сейчас стаб) | Карточка фокус-задачи |
| `DailyFlow/Views/Today/TaskRowView.swift` | Заменить (сейчас стаб) | Строка задачи |
| `DailyFlow/Views/Today/AddTaskBarView.swift` | Создать | Ghost → inline TextField |
| `DailyFlow/Views/Today/RolloverBannerView.swift` | Создать | Плашка переноса |
| `DailyFlowTests/Helpers/InMemoryContainer.swift` | Создать | `TestContainer.make()` |
| `DailyFlowTests/Models/DailyTaskTests.swift` | Создать | Тесты инициализации DailyTask |
| `DailyFlowTests/Services/TaskServiceTests.swift` | Создать | Тесты бизнес-логики |
| `CLAUDE.md` | Изменить | Синхронизация (раздел «Статус», «Выполненные фичи») |
| `DailyFlow.xcodeproj/` | Создать (через Xcode) | Xcode-проект с двумя таргетами |

---

# Phase 0 — Xcode-проект (выполняет пользователь вручную)

> **Эту фазу subagent-ы не выполняют.** Xcode-проект нельзя создать через bash или генерацией `project.pbxproj` — это делается через GUI Xcode. После выполнения этой фазы пользователь скажет «готово», и контроллер запустит Phase 1+.

### Task 0: Создать `DailyFlow.xcodeproj` через Xcode

**Files:**
- Create: `DailyFlow.xcodeproj/` (рядом с папками `DailyFlow/App/`, `DailyFlow/Models/` и т.д. в корне репозитория)

- [ ] **Step 1: File → New → Project → iOS → App → Next**

- [ ] **Step 2: В диалоге "Choose options" выставить параметры**

| Поле | Значение |
|---|---|
| Product Name | `DailyFlow` |
| Team | `None` (или твой Personal Team, если есть) |
| Organization Identifier | `com.dmitry` |
| Bundle Identifier | `com.dmitry.DailyFlow` (авто) |
| Interface | `SwiftUI` |
| Language | `Swift` |
| Testing System | `Swift Testing with XCTest UI Tests` |
| Storage | `SwiftData` |
| Host in CloudKit | **❌ снять галку** |

- [ ] **Step 3: Next → выбрать папку**

- Локация: **`/Users/dimamironov/DailyFlow/`** (корень репозитория, рядом с папками `DailyFlow/App/`, `DailyFlow/Models/` и т.д.).
- ❌ Снять галку **"Create Git repository on my Mac"** (репозиторий уже есть).
- Жми **Create**.

После создания структура должна быть такой:
```
/Users/dimamironov/DailyFlow/
├── DailyFlow/App/                       ← наши исходники (стабы)
├── DailyFlow/Models/                    ← наши исходники
├── DailyFlow/Views/                     ← наши исходники
├── DailyFlow/Services/                  ← наши исходники
├── DailyFlow/Extensions/                ← наши исходники
├── DailyFlow/Widgets/                   ← наши исходники
├── DailyFlow/                 ← новая папка от Xcode (с автогенерёнными файлами)
│   ├── DailyFlowApp.swift     ← удалить
│   ├── ContentView.swift      ← удалить
│   ├── Item.swift             ← удалить
│   └── Assets.xcassets/       ← оставить
├── DailyFlowTests/            ← пустая, добавим тесты позже
├── DailyFlowUITests/          ← оставить, не используем
├── DailyFlow.xcodeproj/       ← готово
├── docs/
├── CLAUDE.md
└── .claude/
```

- [ ] **Step 4: Удалить автогенерёнки**

В Project Navigator (Xcode) удалить с диска (`Move to Trash`):
- `DailyFlow/DailyFlowApp.swift`
- `DailyFlow/ContentView.swift`
- `DailyFlow/Item.swift`

`DailyFlow/Assets.xcassets/` оставить.

- [ ] **Step 5: Подключить наши исходные папки к таргету `DailyFlow` как synchronized folder references**

Xcode 16+ / Xcode 26 поддерживает **synchronized file system groups** — папка автоматически включает все файлы внутри. Это критично: subagent-ы будут создавать новые `.swift` файлы, и они должны появляться в таргете без ручного добавления.

В Xcode: правый клик по корню Project Navigator → **Add Files to "DailyFlow"…** → выбрать папки в Finder:
- `App`
- `Models`
- `Views`
- `Services`
- `Extensions`

В диалоге Add Files:
- **Added folders: Create folder references** (NOT "Create groups" — синие папки, не жёлтые; так Xcode будет авто-подхватывать новые файлы).
- ✅ **Add to targets: DailyFlow** (только этот один таргет, **не** `DailyFlowTests` и **не** `DailyFlowUITests`).
- ❌ **Copy items if needed** (снять — файлы уже в репозитории).

В Project Navigator папки должны отображаться **синими** (folder reference), а не **жёлтыми** (group). Если вышли жёлтые — удалить (Remove Reference, не Move to Trash) и добавить заново.

Папку `DailyFlow/Widgets/` пока **не добавлять** — для виджета нужен отдельный таргет, это вне scope текущего плана.

- [ ] **Step 6: Создать тестовые подпапки и подключить как folder reference**

В Finder создать пустые директории:
- `DailyFlowTests/Helpers/`
- `DailyFlowTests/Models/`
- `DailyFlowTests/Services/`

В Xcode: правый клик по `DailyFlowTests` (он уже есть в навигаторе как создан Xcode) → **Add Files to "DailyFlow"…** → выбрать каждую из созданных подпапок.

В диалоге:
- **Added folders: Create folder references** (синие папки).
- ✅ **Add to targets: DailyFlowTests** (НЕ `DailyFlow`, НЕ `DailyFlowUITests`).
- ❌ **Copy items if needed**.

Sanity check: в Build Phases таргета `DailyFlowTests` → Compile Sources должны быть видны все три папки (даже пустые).

- [ ] **Step 7: Настроить деплоймент-таргет и тёмную тему**

В Project Navigator выбрать корневой `DailyFlow` (синяя иконка) → таргет `DailyFlow` → вкладка **General**:
- **Minimum Deployments → iOS:** `26.0`.
- **Supported Destinations:** оставить только `iPhone` (удалить `iPad`, `Mac (Mac Catalyst)`, `Apple Vision`, если есть).

Вкладка **Info**:
- Добавить ключ `Appearance` (`UIUserInterfaceStyle`) → значение `Dark`.

Вкладка **Info → Localizations**:
- Удалить `English`, добавить `Russian (ru)` как Development Language.

- [ ] **Step 8: Sanity-check — `xcodebuild` видит проект**

Из терминала (ИЛИ контроллер сделает это после уведомления «готово»):

```bash
cd /Users/dimamironov/DailyFlow
xcodebuild -list -project DailyFlow.xcodeproj
```

Ожидаемо: вывод со списком таргетов и схем, среди них как минимум `DailyFlow`, `DailyFlowTests`, `DailyFlowUITests`.

Дополнительно в Xcode: выбрать схему `DailyFlow`, дестинейшн `iPhone 16 Pro`, нажать **Cmd+B**. Сборка **провалится** с ошибками компиляции вида `Expected declaration` в наших стаб-файлах (`// TODO: implement`) — это норма. Главное, что нет ошибки уровня проекта (типа «no such target» или «scheme not found»).

- [ ] **Step 9: Сообщить контроллеру «готово»**

После выполнения шагов 1–8 пользователь возвращается в чат и пишет «готово» / «xcodeproj создан». Контроллер:
1. Прогоняет `xcodebuild -list` для верификации.
2. Делает первый коммит со скаффолдом проекта (`DailyFlow.xcodeproj/`, `DailyFlowTests/`, `DailyFlowUITests/`, `DailyFlow/Assets.xcassets/`) от имени контроллера, прежде чем запускать subagent-ов.
3. Запускает Phase 1.

---

# Phase 1 — Зависимости (секция 17 спека)

### Task 1: ColorExtensions — палитра + `init(hex:)`

**Files:**
- Replace: `DailyFlow/Extensions/ColorExtensions.swift`

- [ ] **Step 1: Заменить содержимое файла**

```swift
import SwiftUI

extension Color {
    static let bgPrimary     = Color(hex: 0x0D0D0D)
    static let bgCard        = Color(hex: 0x1A1A1A)
    static let accentTeal    = Color(hex: 0x2DD4A0)
    static let accentAmber   = Color(hex: 0xF0A23B)
    static let accentPurple  = Color(hex: 0x9B8AE8)
    static let textPrimary   = Color(hex: 0xF2F2F2)
    static let textSecondary = Color(hex: 0x888888)
    static let textGhost     = Color(hex: 0x666666)

    /// Hex-инициализатор: `Color(hex: 0x2DD4A0)`.
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 2: Запустить `/lint` и убедиться что файл проходит**

Ожидаемо: `swiftformat: 0 issues`, `swiftlint: 0 warnings`.

- [ ] **Step 3: Commit**

```bash
git add DailyFlow/Extensions/ColorExtensions.swift
git commit -m "feat(design): add color tokens and hex initializer"
```

---

### Task 2: ViewExtensions — модификаторы `dfTitle/dfBody/dfCaption/dfCard/dfAccentCard`

**Files:**
- Replace: `DailyFlow/Extensions/ViewExtensions.swift`

- [ ] **Step 1: Заменить содержимое файла**

```swift
import SwiftUI

extension View {
    /// 21pt .medium, цвет text.primary.
    func dfTitle() -> some View {
        font(.system(size: 21, weight: .medium))
            .foregroundStyle(Color.textPrimary)
    }

    /// 13pt .regular, цвет text.primary.
    func dfBody() -> some View {
        font(.system(size: 13, weight: .regular))
            .foregroundStyle(Color.textPrimary)
    }

    /// 10pt, letter-spacing 0.5pt, ALL CAPS, цвет text.ghost.
    func dfCaption() -> some View {
        font(.system(size: 10, weight: .regular))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.textGhost)
    }

    /// Карточка: padding 16/14, фон bgCard, cornerRadius 12.
    func dfCard() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.bgCard, in: .rect(cornerRadius: 12))
    }

    /// Акцентная карточка: фон color.opacity(0.08), левый бордер 3pt color, cornerRadius 12.
    func dfAccentCard(color: Color) -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(color.opacity(0.08), in: .rect(cornerRadius: 12))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(color)
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }
    }
}
```

- [ ] **Step 2: `/lint`**

Ожидаемо: чисто.

- [ ] **Step 3: Commit**

```bash
git add DailyFlow/Extensions/ViewExtensions.swift
git commit -m "feat(design): add df* view modifiers"
```

---

### Task 3: Date+StartOfDay

**Files:**
- Create: `DailyFlow/Extensions/Date+StartOfDay.swift`

- [ ] **Step 1: Создать файл**

```swift
import Foundation

extension Date {
    /// Сокращение для `Calendar.current.startOfDay(for: self)`.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
```

- [ ] **Step 2: `/lint`** — чисто.

- [ ] **Step 3: Commit**

```bash
git add DailyFlow/Extensions/Date+StartOfDay.swift
git commit -m "feat(ext): add Date.startOfDay shortcut"
```

---

### Task 4: Haptics

**Files:**
- Create: `DailyFlow/Extensions/Haptics.swift`

- [ ] **Step 1: Создать файл**

```swift
import UIKit

enum Haptics {
    /// Лёгкий тактильный отклик. См. spec §11.
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
```

- [ ] **Step 2: `/lint`** — чисто.

- [ ] **Step 3: Commit**

```bash
git add DailyFlow/Extensions/Haptics.swift
git commit -m "feat(ext): add Haptics.tap helper"
```

---

# Phase 2 — Модели

### Task 5: DailyTask `@Model`

**Files:**
- Replace: `DailyFlow/Models/DailyTask.swift`
- Test: `DailyFlowTests/Models/DailyTaskTests.swift`
- Test: `DailyFlowTests/Helpers/InMemoryContainer.swift`

- [ ] **Step 1: Создать тестовый helper `InMemoryContainer`**

Создать файл `DailyFlowTests/Helpers/InMemoryContainer.swift`:

```swift
import Foundation
import SwiftData
@testable import DailyFlow

@MainActor
enum TestContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            DailyTask.self,
            Habit.self,
            HabitLog.self,
            JournalEntry.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

- [ ] **Step 2: Написать падающий тест `DailyTaskTests`**

Создать `DailyFlowTests/Models/DailyTaskTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import DailyFlow

@Suite("DailyTask") @MainActor
struct DailyTaskTests {
    @Test("init нормализует date в startOfDay")
    func initNormalizesDate() throws {
        let middleOfDay = Date(timeIntervalSince1970: 1_715_000_000) // произвольная дата
        let task = DailyTask(title: "T", date: middleOfDay)
        #expect(task.date == Calendar.current.startOfDay(for: middleOfDay))
    }

    @Test("init по умолчанию: isCompleted=false, isFocus=false, completedAt=nil")
    func initDefaults() {
        let task = DailyTask(title: "T", date: .now)
        #expect(task.isCompleted == false)
        #expect(task.isFocus == false)
        #expect(task.completedAt == nil)
    }

    @Test("isFocus можно задать через init")
    func initFocusFlag() {
        let task = DailyTask(title: "T", date: .now, isFocus: true)
        #expect(task.isFocus == true)
    }
}
```

- [ ] **Step 3: Запустить тесты — должны провалиться**

В Xcode: Cmd+U. Ожидаемо: compile error (`DailyTask` ещё стаб).

- [ ] **Step 4: Реализовать `DailyTask`**

Заменить `DailyFlow/Models/DailyTask.swift`:

```swift
import Foundation
import SwiftData

@Model
final class DailyTask {
    var id: UUID
    var title: String
    /// Инвариант: максимум одна задача в день имеет `isFocus == true`.
    /// Поддерживается `TaskService.setFocus`.
    var isFocus: Bool
    var isCompleted: Bool
    /// Всегда `Calendar.current.startOfDay(for:)`.
    var date: Date
    var createdAt: Date
    /// Заполняется в `toggleCompletion`, обнуляется при снятии флага.
    var completedAt: Date?

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

- [ ] **Step 5: Тесты падают компиляцией ещё раз: модели Habit/HabitLog/JournalEntry — стабы**

Это ожидаемо. Перейдём к Task 6, после него вернёмся и прогоним тесты.

- [ ] **Step 6: Commit**

```bash
git add DailyFlow/Models/DailyTask.swift DailyFlowTests/
git commit -m "feat(models): add DailyTask @Model + tests"
```

---

### Task 6: Минимальные `@Model` для Habit / HabitLog / JournalEntry

Эти модели нужны только для регистрации в `Schema` (виджет, тесты, превью). Полноценные экраны Привычек/Дневника — отдельные спеки.

**Files:**
- Replace: `DailyFlow/Models/Habit.swift`
- Replace: `DailyFlow/Models/HabitLog.swift`
- Replace: `DailyFlow/Models/JournalEntry.swift`

- [ ] **Step 1: Заменить `DailyFlow/Models/Habit.swift`**

```swift
import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID
    var name: String
    /// Hex без `#`, например `"2DD4A0"`.
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog]

    init(name: String, colorHex: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.logs = []
    }
}
```

- [ ] **Step 2: Заменить `DailyFlow/Models/HabitLog.swift`**

```swift
import Foundation
import SwiftData

@Model
final class HabitLog {
    var id: UUID
    /// startOfDay даты выполнения.
    var date: Date
    var completedAt: Date
    var habit: Habit?

    init(date: Date, habit: Habit) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.completedAt = .now
        self.habit = habit
    }
}
```

- [ ] **Step 3: Заменить `DailyFlow/Models/JournalEntry.swift`**

```swift
import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    /// startOfDay; одна запись на день.
    var date: Date
    /// 1...5
    var moodScore: Int
    var text: String
    var syncedToObsidian: Bool
    var createdAt: Date
    var updatedAt: Date

    init(date: Date, moodScore: Int, text: String = "") {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.moodScore = moodScore
        self.text = text
        self.syncedToObsidian = false
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

- [ ] **Step 4: `/lint`** — чисто.

- [ ] **Step 5: Прогнать тесты `DailyTaskTests`**

В Xcode Cmd+U. Ожидаемо: PASS все 3.

- [ ] **Step 6: Commit**

```bash
git add DailyFlow/Models/Habit.swift DailyFlow/Models/HabitLog.swift DailyFlow/Models/JournalEntry.swift
git commit -m "feat(models): add minimal Habit/HabitLog/JournalEntry stubs"
```

---

# Phase 3 — App caркас (нужен для `ModelContainer` и сборки)

### Task 7: `DailyFlowApp` с `ModelContainer`

**Files:**
- Replace: `DailyFlow/App/DailyFlowApp.swift`

- [ ] **Step 1: Заменить файл**

```swift
import SwiftData
import SwiftUI

@main
struct DailyFlowApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            DailyTask.self,
            Habit.self,
            HabitLog.self,
            JournalEntry.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 2: `/lint`** — чисто.

- [ ] **Step 3: Commit**

```bash
git add DailyFlow/App/DailyFlowApp.swift
git commit -m "feat(app): bootstrap ModelContainer with all four models"
```

---

### Task 8: `ContentView` — `TabView` (заглушка для трёх вкладок)

**Files:**
- Replace: `DailyFlow/App/ContentView.swift`

- [ ] **Step 1: Заменить файл**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Сегодня", systemImage: "checkmark.circle") {
                TodayView()
            }
            Tab("Привычки", systemImage: "square.grid.3x3") {
                ComingSoonView(title: "Привычки")
            }
            Tab("Дневник", systemImage: "book.closed") {
                ComingSoonView(title: "Дневник")
            }
            Tab("Инсайты", systemImage: "chart.bar") {
                ComingSoonView(title: "Инсайты")
            }
        }
        .tint(Color.textPrimary)
        .background(Color.bgPrimary)
    }
}

private struct ComingSoonView: View {
    let title: String

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            Text("Скоро")
                .dfTitle()
        }
        .navigationTitle(title)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Запустить `/build`**

Ожидаемо: `❌` — `TodayView` ещё стаб (`// TODO: implement`). Если ошибка ровно про `TodayView` — это норма, продолжаем. Если другая — починить и зафиксировать.

- [ ] **Step 3: Временно заменить `DailyFlow/Views/Today/TodayView.swift` плейсхолдером, чтобы Phase 2/3 закоммитились зелёными**

```swift
import SwiftUI

struct TodayView: View {
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            Text("Сегодня")
                .dfTitle()
        }
    }
}

#Preview {
    TodayView()
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 4: `/build`** — должен пройти `✅`.

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/App/ContentView.swift DailyFlow/Views/Today/TodayView.swift
git commit -m "feat(app): scaffold TabView with placeholder TodayView"
```

---

# Phase 4 — TaskService (TDD)

### Task 9: `TaskService` namespace + первый тест `add` (TDD)

**Files:**
- Create: `DailyFlow/Services/TaskService.swift`
- Test: `DailyFlowTests/Services/TaskServiceTests.swift`

- [ ] **Step 1: Написать первые два падающих теста для `add`**

Создать `DailyFlowTests/Services/TaskServiceTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import DailyFlow

@Suite("TaskService") @MainActor
struct TaskServiceTests {
    private func makeContext() throws -> ModelContext {
        let container = try TestContainer.make()
        return ModelContext(container)
    }

    @Test("add возвращает nil для пустого title")
    func addReturnsNilForEmptyTitle() throws {
        let ctx = try makeContext()
        let result = TaskService.add(title: "   ", on: .now, in: ctx)
        #expect(result == nil)

        let all = try ctx.fetch(FetchDescriptor<DailyTask>())
        #expect(all.isEmpty)
    }

    @Test("add тримит whitespace и сохраняет очищенный title")
    func addTrimsWhitespace() throws {
        let ctx = try makeContext()
        let task = TaskService.add(title: "  купить хлеб  ", on: .now, in: ctx)
        #expect(task?.title == "купить хлеб")

        let all = try ctx.fetch(FetchDescriptor<DailyTask>())
        #expect(all.count == 1)
        #expect(all.first?.title == "купить хлеб")
    }
}
```

- [ ] **Step 2: Запустить тесты — должны не собраться (нет `TaskService`)**

- [ ] **Step 3: Создать `DailyFlow/Services/TaskService.swift` с `add`**

```swift
import Foundation
import SwiftData

/// Stateless namespace бизнес-логики задач.
/// См. spec §4.
@MainActor
enum TaskService {
    /// Создаёт задачу. Возвращает `nil`, если `title` пустой после trim.
    @discardableResult
    static func add(
        title: String,
        isFocus: Bool = false,
        on date: Date,
        in ctx: ModelContext
    ) -> DailyTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let task = DailyTask(title: trimmed, date: date, isFocus: isFocus)
        ctx.insert(task)
        try? ctx.save()
        return task
    }
}
```

- [ ] **Step 4: Прогнать тесты — оба `add*` PASS**

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Services/TaskService.swift DailyFlowTests/Services/TaskServiceTests.swift
git commit -m "feat(service): TaskService.add with trim + tests"
```

---

### Task 10: `toggleCompletion` (TDD)

**Files:**
- Modify: `DailyFlow/Services/TaskService.swift`
- Modify: `DailyFlowTests/Services/TaskServiceTests.swift`

- [ ] **Step 1: Добавить два падающих теста**

Дописать внутрь `struct TaskServiceTests`:

```swift
@Test("toggleCompletion: первая активация ставит completedAt")
func toggleSetsCompletedAt() throws {
    let ctx = try makeContext()
    let task = try #require(TaskService.add(title: "T", on: .now, in: ctx))
    #expect(task.isCompleted == false)
    #expect(task.completedAt == nil)

    TaskService.toggleCompletion(task, in: ctx)

    #expect(task.isCompleted == true)
    #expect(task.completedAt != nil)
}

@Test("toggleCompletion: повторное нажатие сбрасывает completedAt в nil")
func toggleClearsCompletedAt() throws {
    let ctx = try makeContext()
    let task = try #require(TaskService.add(title: "T", on: .now, in: ctx))
    TaskService.toggleCompletion(task, in: ctx)
    #expect(task.isCompleted == true)

    TaskService.toggleCompletion(task, in: ctx)

    #expect(task.isCompleted == false)
    #expect(task.completedAt == nil)
}
```

- [ ] **Step 2: Прогнать — FAIL (метод не существует).**

- [ ] **Step 3: Реализовать `toggleCompletion`**

Добавить в `TaskService`:

```swift
static func toggleCompletion(_ task: DailyTask, in ctx: ModelContext) {
    task.isCompleted.toggle()
    task.completedAt = task.isCompleted ? .now : nil
    try? ctx.save()
}
```

- [ ] **Step 4: Прогнать — PASS.**

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Services/TaskService.swift DailyFlowTests/Services/TaskServiceTests.swift
git commit -m "feat(service): toggleCompletion + tests"
```

---

### Task 11: `setFocus` / `clearFocus` (TDD)

**Files:**
- Modify: `DailyFlow/Services/TaskService.swift`
- Modify: `DailyFlowTests/Services/TaskServiceTests.swift`

- [ ] **Step 1: Добавить три падающих теста**

```swift
@Test("setFocus снимает предыдущий фокус того же дня")
func setFocusClearsPreviousOnSameDay() throws {
    let ctx = try makeContext()
    let day = Date.now.startOfDay
    let a = try #require(TaskService.add(title: "A", on: day, in: ctx))
    let b = try #require(TaskService.add(title: "B", on: day, in: ctx))
    try TaskService.setFocus(a, in: ctx)
    #expect(a.isFocus == true)

    try TaskService.setFocus(b, in: ctx)

    #expect(a.isFocus == false)
    #expect(b.isFocus == true)
    let focused = try ctx.fetch(FetchDescriptor<DailyTask>(
        predicate: #Predicate { $0.isFocus == true }
    ))
    #expect(focused.count == 1)
}

@Test("setFocus не трогает фокус других дней")
func setFocusIsolatedByDay() throws {
    let ctx = try makeContext()
    let today = Date.now.startOfDay
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let yTask = try #require(TaskService.add(title: "Y", on: yesterday, in: ctx))
    try TaskService.setFocus(yTask, in: ctx)

    let tToday = try #require(TaskService.add(title: "T", on: today, in: ctx))
    try TaskService.setFocus(tToday, in: ctx)

    #expect(yTask.isFocus == true)
    #expect(tToday.isFocus == true)
}

@Test("clearFocus(on:) снимает все фокусы дня")
func clearFocusClearsAllOnDay() throws {
    let ctx = try makeContext()
    let day = Date.now.startOfDay
    let a = try #require(TaskService.add(title: "A", on: day, in: ctx))
    try TaskService.setFocus(a, in: ctx)

    try TaskService.clearFocus(on: day, in: ctx)

    #expect(a.isFocus == false)
}
```

- [ ] **Step 2: Прогнать — FAIL.**

- [ ] **Step 3: Реализовать обе функции**

Добавить в `TaskService`:

```swift
/// Атомарно снимает фокус у всех задач этого дня и ставит у переданной.
static func setFocus(_ task: DailyTask, in ctx: ModelContext) throws {
    let day = task.date  // уже startOfDay
    let descriptor = FetchDescriptor<DailyTask>(
        predicate: #Predicate { $0.date == day && $0.isFocus == true }
    )
    for current in try ctx.fetch(descriptor) {
        current.isFocus = false
    }
    task.isFocus = true
    try ctx.save()
}

/// Снимает `isFocus` у всех задач указанного дня.
static func clearFocus(on date: Date, in ctx: ModelContext) throws {
    let day = date.startOfDay
    let descriptor = FetchDescriptor<DailyTask>(
        predicate: #Predicate { $0.date == day && $0.isFocus == true }
    )
    for task in try ctx.fetch(descriptor) {
        task.isFocus = false
    }
    try ctx.save()
}
```

- [ ] **Step 4: Прогнать — PASS.**

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Services/TaskService.swift DailyFlowTests/Services/TaskServiceTests.swift
git commit -m "feat(service): setFocus / clearFocus + tests"
```

---

### Task 12: `updateTitle` + `delete` (TDD)

**Files:**
- Modify: `DailyFlow/Services/TaskService.swift`
- Modify: `DailyFlowTests/Services/TaskServiceTests.swift`

- [ ] **Step 1: Добавить тесты**

```swift
@Test("updateTitle игнорирует пустой ввод")
func updateTitleIgnoresEmpty() throws {
    let ctx = try makeContext()
    let task = try #require(TaskService.add(title: "old", on: .now, in: ctx))

    TaskService.updateTitle(task, to: "   ", in: ctx)

    #expect(task.title == "old")
}

@Test("updateTitle тримит и применяет валидный")
func updateTitleApplies() throws {
    let ctx = try makeContext()
    let task = try #require(TaskService.add(title: "old", on: .now, in: ctx))

    TaskService.updateTitle(task, to: "  new  ", in: ctx)

    #expect(task.title == "new")
}

@Test("delete удаляет задачу из контекста")
func deleteRemovesTask() throws {
    let ctx = try makeContext()
    let task = try #require(TaskService.add(title: "T", on: .now, in: ctx))
    #expect(try ctx.fetch(FetchDescriptor<DailyTask>()).count == 1)

    TaskService.delete(task, in: ctx)

    #expect(try ctx.fetch(FetchDescriptor<DailyTask>()).isEmpty)
}
```

- [ ] **Step 2: Прогнать — FAIL.**

- [ ] **Step 3: Реализовать**

Добавить в `TaskService`:

```swift
/// Игнорирует пустой title (откат к старому значению).
static func updateTitle(_ task: DailyTask, to title: String, in ctx: ModelContext) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    task.title = trimmed
    try? ctx.save()
}

static func delete(_ task: DailyTask, in ctx: ModelContext) {
    ctx.delete(task)
    try? ctx.save()
}
```

- [ ] **Step 4: Прогнать — PASS.**

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Services/TaskService.swift DailyFlowTests/Services/TaskServiceTests.swift
git commit -m "feat(service): updateTitle + delete + tests"
```

---

### Task 13: `rolloverPending` (TDD)

**Files:**
- Modify: `DailyFlow/Services/TaskService.swift`
- Modify: `DailyFlowTests/Services/TaskServiceTests.swift`

- [ ] **Step 1: Добавить тесты**

```swift
@Test("rolloverPending переносит незавершённые задачи прошлых дней на target")
func rolloverMovesIncomplete() throws {
    let ctx = try makeContext()
    let today = Date.now.startOfDay
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
    _ = try #require(TaskService.add(title: "Y1", on: yesterday, in: ctx))
    _ = try #require(TaskService.add(title: "Y2", on: twoDaysAgo, in: ctx))

    let moved = try TaskService.rolloverPending(into: today, in: ctx)

    #expect(moved == 2)
    let onToday = try ctx.fetch(FetchDescriptor<DailyTask>(
        predicate: #Predicate { $0.date == today }
    ))
    #expect(onToday.count == 2)
}

@Test("rolloverPending сбрасывает isFocus у переносимых задач")
func rolloverDropsFocusFlag() throws {
    let ctx = try makeContext()
    let today = Date.now.startOfDay
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let yTask = try #require(TaskService.add(title: "Y", on: yesterday, in: ctx))
    try TaskService.setFocus(yTask, in: ctx)
    #expect(yTask.isFocus == true)

    _ = try TaskService.rolloverPending(into: today, in: ctx)

    #expect(yTask.isFocus == false)
    #expect(yTask.date == today)
    #expect(yTask.title == "Y")
}

@Test("rolloverPending не трогает выполненные задачи")
func rolloverSkipsCompleted() throws {
    let ctx = try makeContext()
    let today = Date.now.startOfDay
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let done = try #require(TaskService.add(title: "Done", on: yesterday, in: ctx))
    TaskService.toggleCompletion(done, in: ctx)

    let moved = try TaskService.rolloverPending(into: today, in: ctx)

    #expect(moved == 0)
    #expect(done.date == yesterday)
}
```

- [ ] **Step 2: Прогнать — FAIL.**

- [ ] **Step 3: Реализовать**

Добавить в `TaskService`:

```swift
/// Переносит все незавершённые задачи с дат < target на target.
/// При переносе: `date = target.startOfDay`, `isFocus = false`.
@discardableResult
static func rolloverPending(into target: Date, in ctx: ModelContext) throws -> Int {
    let day = target.startOfDay
    let descriptor = FetchDescriptor<DailyTask>(
        predicate: #Predicate { $0.date < day && $0.isCompleted == false }
    )
    let tasks = try ctx.fetch(descriptor)
    for task in tasks {
        task.date = day
        task.isFocus = false
    }
    try ctx.save()
    return tasks.count
}
```

- [ ] **Step 4: Прогнать — PASS.**

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Services/TaskService.swift DailyFlowTests/Services/TaskServiceTests.swift
git commit -m "feat(service): rolloverPending + tests"
```

---

### Task 14: `discardPending` (TDD)

**Files:**
- Modify: `DailyFlow/Services/TaskService.swift`
- Modify: `DailyFlowTests/Services/TaskServiceTests.swift`

- [ ] **Step 1: Добавить тест**

```swift
@Test("discardPending удаляет только прошлые незавершённые задачи")
func discardOnlyPastIncomplete() throws {
    let ctx = try makeContext()
    let today = Date.now.startOfDay
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

    let pastIncomplete = try #require(TaskService.add(title: "PI", on: yesterday, in: ctx))
    let pastDone = try #require(TaskService.add(title: "PD", on: yesterday, in: ctx))
    TaskService.toggleCompletion(pastDone, in: ctx)
    let todayTask = try #require(TaskService.add(title: "TT", on: today, in: ctx))

    let removed = try TaskService.discardPending(before: today, in: ctx)

    #expect(removed == 1)
    let all = try ctx.fetch(FetchDescriptor<DailyTask>())
    let titles = Set(all.map(\.title))
    #expect(titles == ["PD", "TT"])
    _ = pastIncomplete  // удалена; ссылка инвалидна
    _ = todayTask
}
```

- [ ] **Step 2: Прогнать — FAIL.**

- [ ] **Step 3: Реализовать**

Добавить в `TaskService`:

```swift
/// Удаляет все незавершённые задачи с дат < date.
@discardableResult
static func discardPending(before date: Date, in ctx: ModelContext) throws -> Int {
    let day = date.startOfDay
    let descriptor = FetchDescriptor<DailyTask>(
        predicate: #Predicate { $0.date < day && $0.isCompleted == false }
    )
    let tasks = try ctx.fetch(descriptor)
    for task in tasks { ctx.delete(task) }
    try ctx.save()
    return tasks.count
}
```

- [ ] **Step 4: Прогнать — PASS. Полный suite TaskService должен быть зелёным (12 тестов).**

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Services/TaskService.swift DailyFlowTests/Services/TaskServiceTests.swift
git commit -m "feat(service): discardPending + tests"
```

---

# Phase 5 — PreviewContainer

### Task 15: `ModelContainer.preview(_:)` фабрика для `#Preview`

**Files:**
- Create: `DailyFlow/Extensions/PreviewContainer.swift`

- [ ] **Step 1: Создать файл**

```swift
import Foundation
import SwiftData

/// Сценарии для `#Preview`. См. spec §14.6.
enum PreviewScenario {
    case empty
    case onlyFocus
    case mixed
    case withRollover
    case editingFirst
}

extension ModelContainer {
    /// In-memory контейнер с предзаполненными данными для превью.
    @MainActor
    static func preview(_ scenario: PreviewScenario) -> ModelContainer {
        let schema = Schema([
            DailyTask.self,
            Habit.self,
            HabitLog.self,
            JournalEntry.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: schema, configurations: [config])
        seed(scenario, in: container.mainContext)
        return container
    }

    @MainActor
    private static func seed(_ scenario: PreviewScenario, in ctx: ModelContext) {
        let today = Date.now.startOfDay
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        switch scenario {
        case .empty:
            return
        case .onlyFocus:
            let focus = DailyTask(title: "Закрыть бюджет на май", date: today, isFocus: true)
            ctx.insert(focus)
        case .mixed:
            let focus = DailyTask(title: "Доделать спек экрана «Сегодня»", date: today, isFocus: true)
            ctx.insert(focus)
            ctx.insert(DailyTask(title: "Купить хлеб", date: today))
            let done = DailyTask(title: "Запустить тесты", date: today)
            done.isCompleted = true
            done.completedAt = .now
            ctx.insert(done)
            ctx.insert(DailyTask(title: "Позвонить маме", date: today))
        case .withRollover:
            ctx.insert(DailyTask(title: "Полить цветы", date: yesterday))
            ctx.insert(DailyTask(title: "Заменить лампочку", date: yesterday))
            ctx.insert(DailyTask(title: "Сегодняшняя задача", date: today))
        case .editingFirst:
            ctx.insert(DailyTask(title: "Редактируется", date: today))
            ctx.insert(DailyTask(title: "Обычная", date: today))
        }
        try? ctx.save()
    }
}
```

- [ ] **Step 2: `/lint`** — чисто.

- [ ] **Step 3: Commit**

```bash
git add DailyFlow/Extensions/PreviewContainer.swift
git commit -m "feat(preview): add ModelContainer.preview(_:) factory"
```

---

# Phase 6 — Today screen views (bottom-up)

### Task 16: `AddTaskBarView`

**Files:**
- Create: `DailyFlow/Views/Today/AddTaskBarView.swift`

- [ ] **Step 1: Создать файл**

```swift
import SwiftUI

/// Quick-capture: ghost-кнопка → inline TextField. См. spec §8.4.
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

            TextField(
                focused ? "Новая задача…" : "Добавить задачу",
                text: $text
            )
            .focused($focused)
            .submitLabel(.return)
            .onSubmit(submit)
            .foregroundStyle(focused ? Color.textPrimary : Color.textGhost)
            .font(.system(size: 13, weight: .regular))
            .tint(Color.accentTeal)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if focused {
                Rectangle()
                    .fill(Color.accentTeal)
                    .frame(height: 1)
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
        text = ""  // готов к следующей; focused остаётся true
    }
}

#Preview("Idle") {
    StatefulPreview()
        .padding(.horizontal, 16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}

private struct StatefulPreview: View {
    @State private var text = ""

    var body: some View {
        AddTaskBarView(text: $text, onSubmit: { _ in })
    }
}
```

- [ ] **Step 2: `/lint`** — чисто.

- [ ] **Step 3: Открыть превью в Xcode (Editor → Canvas, ⌥⌘P).**

Ожидаемо: ghost-кнопка с плюсиком и текстом «Добавить задачу» серого цвета.

- [ ] **Step 4: Commit**

```bash
git add DailyFlow/Views/Today/AddTaskBarView.swift
git commit -m "feat(today): AddTaskBarView (ghost → inline TextField)"
```

---

### Task 17: `TaskRowView`

**Files:**
- Replace: `DailyFlow/Views/Today/TaskRowView.swift`

- [ ] **Step 1: Заменить файл**

```swift
import SwiftData
import SwiftUI

/// Строка задачи в списке. См. spec §8.3.
struct TaskRowView: View {
    let task: DailyTask
    let isEditing: Bool
    let onToggle: () -> Void
    let onStartEdit: () -> Void
    let onFinishEdit: (String) -> Void
    let onSetFocus: () -> Void
    let onDelete: () -> Void

    @State private var draftTitle: String = ""
    @FocusState private var editFieldFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            checkbox
            titleArea
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
        .contextMenu {
            Button(task.isFocus ? "Снять с фокуса" : "Сделать фокусом") {
                Haptics.tap(.medium)
                onSetFocus()
            }
            Button("Изменить") { onStartEdit() }
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
        .onChange(of: isEditing) { _, newValue in
            if newValue {
                draftTitle = task.title
                editFieldFocused = true
            }
        }
    }

    private var checkbox: some View {
        Button(action: {
            Haptics.tap(.medium)
            onToggle()
        }, label: {
            ZStack {
                Circle()
                    .strokeBorder(Color(hex: 0x333333), lineWidth: 1.5)
                    .frame(width: 15, height: 15)
                if task.isCompleted {
                    Circle()
                        .fill(Color.accentTeal)
                        .frame(width: 15, height: 15)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44, alignment: .center)
            .contentShape(.rect)
        })
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: task.isCompleted)
    }

    @ViewBuilder
    private var titleArea: some View {
        if isEditing {
            TextField("", text: $draftTitle)
                .focused($editFieldFocused)
                .submitLabel(.done)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.textPrimary)
                .tint(Color.accentTeal)
                .padding(.top, 12)
                .onSubmit { onFinishEdit(draftTitle) }
        } else {
            Text(task.title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(task.isCompleted ? Color.textSecondary : Color.textPrimary)
                .strikethrough(task.isCompleted, color: Color.textSecondary)
                .opacity(task.isCompleted ? 0.5 : 1.0)
                .lineLimit(2)
                .padding(.top, 12)
                .animation(.easeInOut(duration: 0.15), value: task.isCompleted)
        }
    }
}

#Preview("Mixed states") {
    let container = ModelContainer.preview(.mixed)
    let tasks = try! container.mainContext.fetch(FetchDescriptor<DailyTask>())
    return VStack(spacing: 0) {
        ForEach(tasks) { task in
            TaskRowView(
                task: task,
                isEditing: false,
                onToggle: {},
                onStartEdit: {},
                onFinishEdit: { _ in },
                onSetFocus: {},
                onDelete: {}
            )
        }
    }
    .padding(.horizontal, 16)
    .background(Color.bgPrimary)
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: `/lint`** — чисто.

- [ ] **Step 3: Превью отрендерилось — видны 4 строки с разными состояниями.**

- [ ] **Step 4: Commit**

```bash
git add DailyFlow/Views/Today/TaskRowView.swift
git commit -m "feat(today): TaskRowView with checkbox/edit/swipe/contextMenu"
```

---

### Task 18: `FocusCardView`

**Files:**
- Replace: `DailyFlow/Views/Today/FocusCardView.swift`

- [ ] **Step 1: Заменить файл**

```swift
import SwiftData
import SwiftUI

/// Карточка фокус-задачи. См. spec §8.2.
struct FocusCardView: View {
    let task: DailyTask
    let isEditing: Bool
    let onToggle: () -> Void
    let onStartEdit: () -> Void
    let onFinishEdit: (String) -> Void
    let onClearFocus: () -> Void
    let onDelete: () -> Void

    @State private var draftTitle: String = ""
    @FocusState private var editFieldFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ФОКУС")
                    .font(.system(size: 10, weight: .regular))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.accentTeal)

                titleArea
            }
            Spacer(minLength: 0)
            checkbox
        }
        .dfAccentCard(color: Color.accentTeal)
        .contextMenu {
            Button("Снять с фокуса") {
                Haptics.tap(.medium)
                onClearFocus()
            }
            Button("Изменить") { onStartEdit() }
            Button("Удалить", role: .destructive) {
                Haptics.tap(.heavy)
                onDelete()
            }
        }
        .onChange(of: isEditing) { _, newValue in
            if newValue {
                draftTitle = task.title
                editFieldFocused = true
            }
        }
    }

    @ViewBuilder
    private var titleArea: some View {
        if isEditing {
            TextField("", text: $draftTitle)
                .focused($editFieldFocused)
                .submitLabel(.done)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.textPrimary)
                .tint(Color.accentTeal)
                .onSubmit { onFinishEdit(draftTitle) }
        } else {
            Text(task.title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(task.isCompleted ? Color.textSecondary : Color.textPrimary)
                .strikethrough(task.isCompleted, color: Color.textSecondary)
                .opacity(task.isCompleted ? 0.5 : 1.0)
                .lineLimit(3)
        }
    }

    private var checkbox: some View {
        Button(action: {
            Haptics.tap(.medium)
            onToggle()
        }, label: {
            ZStack {
                Circle()
                    .strokeBorder(Color(hex: 0x333333), lineWidth: 1.5)
                    .frame(width: 15, height: 15)
                if task.isCompleted {
                    Circle()
                        .fill(Color.accentTeal)
                        .frame(width: 15, height: 15)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44, alignment: .center)
            .contentShape(.rect)
        })
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: task.isCompleted)
    }
}

#Preview("Focus card") {
    let container = ModelContainer.preview(.onlyFocus)
    let focus = try! container.mainContext.fetch(
        FetchDescriptor<DailyTask>(predicate: #Predicate { $0.isFocus == true })
    ).first!
    return FocusCardView(
        task: focus,
        isEditing: false,
        onToggle: {},
        onStartEdit: {},
        onFinishEdit: { _ in },
        onClearFocus: {},
        onDelete: {}
    )
    .padding(.horizontal, 16)
    .background(Color.bgPrimary)
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: `/lint`** — чисто.

- [ ] **Step 3: Превью видно: акцентная карточка с лейблом «ФОКУС» и заголовком задачи.**

- [ ] **Step 4: Commit**

```bash
git add DailyFlow/Views/Today/FocusCardView.swift
git commit -m "feat(today): FocusCardView (accent card + edit + contextMenu)"
```

---

### Task 19: `RolloverBannerView`

**Files:**
- Create: `DailyFlow/Views/Today/RolloverBannerView.swift`

- [ ] **Step 1: Создать файл**

```swift
import SwiftUI

/// Плашка переноса незавершённых задач. См. spec §8.5.
struct RolloverBannerView: View {
    let count: Int
    let onMove: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Незавершённых: \(count)")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.textSecondary)

            Spacer(minLength: 0)

            Button {
                Haptics.tap(.light)
                onMove()
            } label: {
                Text("Перенести")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.accentTeal)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap(.medium)
                onDiscard()
            } label: {
                Text("Очистить")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .dfCard()
    }
}

#Preview("With 3 pending") {
    RolloverBannerView(count: 3, onMove: {}, onDiscard: {})
        .padding(.horizontal, 16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: `/lint`** — чисто.

- [ ] **Step 3: Превью: тёмная карточка, слева счётчик, справа две кнопки.**

- [ ] **Step 4: Commit**

```bash
git add DailyFlow/Views/Today/RolloverBannerView.swift
git commit -m "feat(today): RolloverBannerView (move/discard)"
```

---

### Task 20: `TodayContentView` — главный экран

**Files:**
- Create: `DailyFlow/Views/Today/TodayContentView.swift`

- [ ] **Step 1: Создать файл**

```swift
import SwiftData
import SwiftUI

/// Главный UI экрана «Сегодня». См. spec §6, §7.
struct TodayContentView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var todayTasks: [DailyTask]
    @Query private var pendingFromPast: [DailyTask]

    @State private var addBarText = ""
    @State private var editingTaskId: UUID?

    private let dateAnchor: Date

    init(dateAnchor: Date) {
        self.dateAnchor = dateAnchor
        let today = dateAnchor // ← локальный захват, обязателен для #Predicate
        _todayTasks = Query(
            filter: #Predicate<DailyTask> { $0.date == today },
            sort: [SortDescriptor(\.createdAt, order: .forward)]
        )
        _pendingFromPast = Query(
            filter: #Predicate<DailyTask> { $0.date < today && $0.isCompleted == false }
        )
    }

    private var focus: DailyTask? { todayTasks.first { $0.isFocus } }
    private var regular: [DailyTask] { todayTasks.filter { !$0.isFocus } }
    private var completedCount: Int { todayTasks.filter(\.isCompleted).count }
    private var totalCount: Int { todayTasks.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                rolloverBanner
                focusCard
                tasksHeader
                tasksList
                addBar
            }
            .padding(.horizontal, 16)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: focus?.id)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: pendingFromPast.isEmpty)
        }
        .background(Color.bgPrimary)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.headerCaption(for: dateAnchor))
                .dfCaption()
            Text("Сегодня")
                .dfTitle()
        }
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private static func headerCaption(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date).uppercased()
    }

    // MARK: Sections

    @ViewBuilder
    private var rolloverBanner: some View {
        if !pendingFromPast.isEmpty {
            RolloverBannerView(
                count: pendingFromPast.count,
                onMove: { try? TaskService.rolloverPending(into: dateAnchor, in: ctx) },
                onDiscard: { try? TaskService.discardPending(before: dateAnchor, in: ctx) }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var focusCard: some View {
        if let focus {
            FocusCardView(
                task: focus,
                isEditing: editingTaskId == focus.id,
                onToggle: { TaskService.toggleCompletion(focus, in: ctx) },
                onStartEdit: { editingTaskId = focus.id },
                onFinishEdit: { commitEdit(focus, $0) },
                onClearFocus: { try? TaskService.clearFocus(on: dateAnchor, in: ctx) },
                onDelete: { TaskService.delete(focus, in: ctx) }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var tasksHeader: some View {
        Text("Задачи — \(completedCount)/\(totalCount)")
            .dfCaption()
            .padding(.top, 4)
    }

    private var tasksList: some View {
        LazyVStack(spacing: 0) {
            ForEach(regular) { task in
                TaskRowView(
                    task: task,
                    isEditing: editingTaskId == task.id,
                    onToggle: { TaskService.toggleCompletion(task, in: ctx) },
                    onStartEdit: { editingTaskId = task.id },
                    onFinishEdit: { commitEdit(task, $0) },
                    onSetFocus: { handleFocusToggle(task) },
                    onDelete: { TaskService.delete(task, in: ctx) }
                )
            }
        }
    }

    private var addBar: some View {
        AddTaskBarView(
            text: $addBarText,
            onSubmit: { TaskService.add(title: $0, on: dateAnchor, in: ctx) }
        )
    }

    // MARK: Helpers

    private func commitEdit(_ task: DailyTask, _ newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != task.title {
            TaskService.updateTitle(task, to: trimmed, in: ctx)
            Haptics.tap(.light)
        }
        editingTaskId = nil
    }

    private func handleFocusToggle(_ task: DailyTask) {
        if task.isFocus {
            try? TaskService.clearFocus(on: dateAnchor, in: ctx)
        } else {
            try? TaskService.setFocus(task, in: ctx)
        }
    }
}

#Preview("Empty") {
    TodayContentView(dateAnchor: .now.startOfDay)
        .modelContainer(.preview(.empty))
        .preferredColorScheme(.dark)
}

#Preview("Only focus") {
    TodayContentView(dateAnchor: .now.startOfDay)
        .modelContainer(.preview(.onlyFocus))
        .preferredColorScheme(.dark)
}

#Preview("Mixed") {
    TodayContentView(dateAnchor: .now.startOfDay)
        .modelContainer(.preview(.mixed))
        .preferredColorScheme(.dark)
}

#Preview("With banner") {
    TodayContentView(dateAnchor: .now.startOfDay)
        .modelContainer(.preview(.withRollover))
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Проверить лимит строк**

```bash
wc -l DailyFlow/Views/Today/TodayContentView.swift
```

Ожидаемо: ≤ 200 (лимит swiftlint warning). Спек ставит мягкий лимит ≤ 130 — если превышено, выдели header в отдельный private view внутри файла, но не в новый файл.

- [ ] **Step 3: `/lint`** — чисто.

- [ ] **Step 4: Прогнать все 4 превью в Xcode**

Ожидаемо:
- `Empty` — только заголовок и AddBar.
- `Only focus` — заголовок, акцентная карточка, лейбл `ЗАДАЧИ — 0/1`, AddBar.
- `Mixed` — заголовок, фокус-карточка, лейбл `1/4`, 3 строки задач, AddBar.
- `With banner` — заголовок, банер «Незавершённых: 2», лейбл `0/1`, 1 строка, AddBar.

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Views/Today/TodayContentView.swift
git commit -m "feat(today): TodayContentView with @Query, focus, rollover, add"
```

---

### Task 21: `TodayView` — обёртка с `dateAnchor`

**Files:**
- Replace: `DailyFlow/Views/Today/TodayView.swift`

- [ ] **Step 1: Заменить файл (вместо плейсхолдера из Task 8)**

```swift
import SwiftUI

/// Обёртка для cross-midnight: при возврате в `.active` пересчитывает `dateAnchor`,
/// а `.id(dateAnchor)` форсит re-init `TodayContentView`. См. spec §6.1.
struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dateAnchor = Date.now.startOfDay

    var body: some View {
        TodayContentView(dateAnchor: dateAnchor)
            .id(dateAnchor)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                let now = Date.now.startOfDay
                if now != dateAnchor {
                    dateAnchor = now
                }
            }
    }
}

#Preview("Mixed via TodayView") {
    TodayView()
        .modelContainer(.preview(.mixed))
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: `/lint`** — чисто.

- [ ] **Step 3: `/build`** — `✅ build ok`.

- [ ] **Step 4: Запустить в симуляторе через `/sim`** или вручную (Cmd+R в Xcode)

Sanity check (быстрый smoke-тест):
- На вкладке «Сегодня» виден заголовок с датой и «Сегодня».
- Тап на ghost-кнопку «Добавить задачу» открывает клавиатуру, ввести «Тест», Return — задача появилась в списке.
- Тап по чекбоксу — задача отмечается, текст приглушается.
- Long-press на задаче — `.contextMenu` с тремя пунктами.
- «Сделать фокусом» → задача переезжает в акцентную карточку наверху.

- [ ] **Step 5: Commit**

```bash
git add DailyFlow/Views/Today/TodayView.swift
git commit -m "feat(today): TodayView wrapper with scenePhase-based dateAnchor"
```

---

# Phase 7 — Финальная верификация

### Task 22: Полный прогон линт + тесты + билд

**Files:** —

- [ ] **Step 1: `/format`** — применить swiftformat ко всему проекту, чтобы ничего не дрифтило.

- [ ] **Step 2: `/lint`** — должно быть `swiftformat: 0 issues, swiftlint: 0 warnings, 0 errors`.

- [ ] **Step 3: Прогнать все тесты**

```bash
xcodebuild test \
  -project DailyFlow.xcodeproj \
  -scheme DailyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  | xcbeautify
```

Ожидаемо: все 12 тестов `TaskServiceTests` + 3 теста `DailyTaskTests` PASS. Итого 15 тестов зелёных.

- [ ] **Step 4: `/build`** — `✅ build ok`.

- [ ] **Step 5: Если есть незакоммиченные правки от автоформата — commit**

```bash
git add -A
git commit -m "chore: apply swiftformat across codebase" --allow-empty
```

---

### Task 23: Обновить `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: В разделе «Статус» заменить строку**

Было:
```
- **Статус:** 🟡 Скаффолдинг завершён, дизайн-токены и кастомный `.claude/` плагин настроены. Спек экрана «Сегодня» утверждён ([`docs/superpowers/specs/2026-05-07-today-screen-design.md`](./docs/superpowers/specs/2026-05-07-today-screen-design.md)). Следующий шаг — `superpowers:writing-plans` в новой сессии.
```

Стало:
```
- **Статус:** 🟢 Экран «Сегодня» реализован (см. план [`docs/superpowers/plans/2026-05-07-today-screen.md`](./docs/superpowers/plans/2026-05-07-today-screen.md)). Дизайн-токены, `TaskService` и базовый каркас приложения готовы. Следующий шаг — спек экрана «Привычки».
```

- [ ] **Step 2: В разделе «Выполненные фичи» отметить экран**

Заменить:
```
- [ ] Экран «Сегодня» (план реализации — следующий шаг)
```

На:
```
- [x] Экран «Сегодня» — `TodayView` + `TodayContentView` + `FocusCardView` + `TaskRowView` + `AddTaskBarView` + `RolloverBannerView`
- [x] `TaskService` (add/toggle/setFocus/clearFocus/updateTitle/delete/rolloverPending/discardPending) + 12 тестов
- [x] Дизайн-токены (`Color.bgPrimary` … `.textGhost`) + модификаторы `dfTitle/dfBody/dfCaption/dfCard/dfAccentCard`
- [x] App-каркас (`DailyFlowApp` с `ModelContainer` × 4 модели, `ContentView` TabView с тремя «Скоро»-заглушками)
```

- [ ] **Step 3: В разделе «Структура файлов» убрать комментарии-плейсхолдеры**

В блоке файлового дерева убедиться, что присутствуют:
```
DailyFlow/
  DailyFlow/Views/Today/
    TodayContentView.swift
    AddTaskBarView.swift
    RolloverBannerView.swift
  DailyFlow/Services/
    TaskService.swift
  DailyFlow/Extensions/
    Haptics.swift
    Date+StartOfDay.swift
    PreviewContainer.swift
  DailyFlowTests/
    Helpers/InMemoryContainer.swift
    DailyFlow/Models/DailyTaskTests.swift
    DailyFlow/Services/TaskServiceTests.swift
```

(Они уже задекларированы в текущем `CLAUDE.md` — просто проверить, что описание соответствует реальности.)

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: mark Today screen done in CLAUDE.md"
```

---

## Definition of Done

- [ ] `/lint` — ноль warnings, ноль errors.
- [ ] `/build` — `✅ build ok`.
- [ ] 15 тестов (3 `DailyTaskTests` + 12 `TaskServiceTests`) — все зелёные.
- [ ] 5+ превью `TodayContentView` (`.empty`, `.onlyFocus`, `.mixed`, `.withRollover`) рендерятся в Xcode Canvas.
- [ ] Smoke-test в симуляторе: добавление, toggle, setFocus, contextMenu delete, swipe delete, rollover, discard.
- [ ] `CLAUDE.md` обновлён.
- [ ] Все 23 коммита читаемые, по одному на задачу.
