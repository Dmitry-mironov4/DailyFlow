# Calendar Integration & Interactive Widgets — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить синхронизацию задач с EventKit-календарём и интерактивный виджет WidgetKit с чекбоксами через AppIntents.

**Architecture:** CalendarService — stateless enum-namespace (как TaskService), вызывается из TaskService при наличии scheduledTime. Виджет — отдельный Extension target (DailyFlowWidgets), читает SwiftData через App Group, кнопки через ToggleTaskIntent : AppIntent.

**Tech Stack:** EventKit, WidgetKit, AppIntents, SwiftData, SwiftUI, Swift 6

---

## Карта файлов

| Действие | Файл | Что делает |
|---|---|---|
| Изменить | `DailyFlow/Models/DailyTask.swift` | Добавить `scheduledTime`, `calendarEventID` |
| Создать | `DailyFlow/Services/CalendarService.swift` | EventKit CRUD |
| Изменить | `DailyFlow/Services/TaskService.swift` | Вызовы CalendarService, `setScheduledTime` |
| Изменить | `DailyFlow/Views/Today/AddTaskBarView.swift` | TimePicker, изменить `onSubmit` сигнатуру |
| Изменить | `DailyFlow/Views/Today/TodayContentView.swift` | Обновить вызов `onSubmit` |
| Изменить | `DailyFlow/Views/Today/TaskRowView.swift` | Показывать время рядом с заголовком |
| Изменить | `DailyFlow/Widgets/DailyFlowWidgets.swift` | Опустошить (код переехал в ext. target) |
| Создать | `DailyFlowWidgets/DailyFlowWidgets.swift` | Widget entry, provider, entryView |
| Создать | `DailyFlowWidgets/ToggleTaskIntent.swift` | AppIntent для toggle |
| Создать | `DailyFlowWidgets/DailyFlowWidgets.entitlements` | App Group для виджета |
| Создать | `DailyFlow/DailyFlow.entitlements` | App Group для основного приложения |
| Изменить | `DailyFlow.xcodeproj/project.pbxproj` | Widget Extension target + NSCalendars ключ + Code Sign Entitlements |

---

## Task 1: DailyTask — новые поля

**Files:**
- Modify: `DailyFlow/Models/DailyTask.swift`

- [ ] **Шаг 1.1: Добавить поля scheduledTime и calendarEventID**

Заменить содержимое `DailyFlow/Models/DailyTask.swift`:

```swift
import Foundation
import SwiftData

@Model
final class DailyTask {
    var id: UUID
    var title: String
    var isFocus: Bool
    var isCompleted: Bool
    var date: Date
    var createdAt: Date
    var completedAt: Date?
    var scheduledTime: Date?
    var calendarEventID: String?

    init(title: String, date: Date, isFocus: Bool = false, scheduledTime: Date? = nil) {
        id = UUID()
        self.title = title
        self.isFocus = isFocus
        isCompleted = false
        self.date = Calendar.current.startOfDay(for: date)
        createdAt = .now
        completedAt = nil
        self.scheduledTime = scheduledTime
        calendarEventID = nil
    }
}
```

- [ ] **Шаг 1.2: Commit**

```bash
git add DailyFlow/Models/DailyTask.swift
git commit -m "feat(model): add scheduledTime and calendarEventID to DailyTask"
```

---

## Task 2: CalendarService

**Files:**
- Create: `DailyFlow/Services/CalendarService.swift`

- [ ] **Шаг 2.1: Создать CalendarService**

```swift
import EventKit
import Foundation

enum CalendarService {
    static let store = EKEventStore()

    static func requestAccess() async -> Bool {
        await (try? store.requestWriteOnlyAccessToEvents()) ?? false
    }

    @discardableResult
    static func sync(_ task: DailyTask) -> String? {
        guard let scheduledTime = task.scheduledTime else { return nil }

        let event: EKEvent
        if let existingID = task.calendarEventID,
           let existing = store.event(withIdentifier: existingID) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
        }

        event.title = task.title
        event.startDate = scheduledTime
        event.endDate = scheduledTime.addingTimeInterval(3600)
        event.calendar = store.defaultCalendarForNewEvents

        try? store.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    static func remove(eventID: String) {
        guard let event = store.event(withIdentifier: eventID) else { return }
        try? store.remove(event, span: .thisEvent)
    }
}
```

- [ ] **Шаг 2.2: Commit**

```bash
git add DailyFlow/Services/CalendarService.swift
git commit -m "feat(service): add CalendarService for EventKit sync"
```

---

## Task 3: TaskService — интеграция с CalendarService

**Files:**
- Modify: `DailyFlow/Services/TaskService.swift`

- [ ] **Шаг 3.1: Обновить TaskService**

Заменить содержимое `DailyFlow/Services/TaskService.swift`:

```swift
import Foundation
import SwiftData

enum TaskService {
    @discardableResult
    static func add(
        title: String,
        scheduledTime: Date? = nil,
        isFocus: Bool = false,
        on date: Date,
        in ctx: ModelContext
    ) -> DailyTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let task = DailyTask(title: trimmed, date: date, isFocus: isFocus, scheduledTime: scheduledTime)
        ctx.insert(task)
        task.calendarEventID = CalendarService.sync(task)
        return task
    }

    static func toggleCompletion(_ task: DailyTask, in ctx: ModelContext) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? .now : nil
        try? ctx.save()
    }

    static func setFocus(_ task: DailyTask, in ctx: ModelContext) throws {
        let targetDay = task.date
        let all = try ctx.fetch(FetchDescriptor<DailyTask>())
        for existing in all where existing.date == targetDay && existing.isFocus {
            existing.isFocus = false
        }
        task.isFocus = true
        try ctx.save()
    }

    static func clearFocus(on date: Date, in ctx: ModelContext) throws {
        let day = Calendar.current.startOfDay(for: date)
        let all = try ctx.fetch(FetchDescriptor<DailyTask>())
        for task in all where task.date == day && task.isFocus {
            task.isFocus = false
        }
        try ctx.save()
    }

    static func delete(_ task: DailyTask, in ctx: ModelContext) {
        if let eventID = task.calendarEventID {
            CalendarService.remove(eventID: eventID)
        }
        ctx.delete(task)
        try? ctx.save()
    }

    static func updateTitle(_ task: DailyTask, to title: String, in ctx: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        task.title = trimmed
        task.calendarEventID = CalendarService.sync(task)
        try? ctx.save()
    }

    static func setScheduledTime(_ task: DailyTask, time: Date?, in ctx: ModelContext) {
        task.scheduledTime = time
        if let time, !time.isZero {
            task.calendarEventID = CalendarService.sync(task)
        } else if let eventID = task.calendarEventID {
            CalendarService.remove(eventID: eventID)
            task.calendarEventID = nil
        }
        try? ctx.save()
    }

    @discardableResult
    static func rolloverPending(into target: Date, in ctx: ModelContext) throws -> Int {
        let targetDay = Calendar.current.startOfDay(for: target)
        let all = try ctx.fetch(FetchDescriptor<DailyTask>())
        let pending = all.filter { $0.date < targetDay && !$0.isCompleted }
        for task in pending {
            task.date = targetDay
            task.isFocus = false
        }
        try ctx.save()
        return pending.count
    }

    @discardableResult
    static func discardPending(before date: Date, in ctx: ModelContext) throws -> Int {
        let day = Calendar.current.startOfDay(for: date)
        let all = try ctx.fetch(FetchDescriptor<DailyTask>())
        let pending = all.filter { $0.date < day && !$0.isCompleted }
        for task in pending {
            ctx.delete(task)
        }
        try ctx.save()
        return pending.count
    }
}
```

Заметка: `time.isZero` не существует для Date. Нужна другая проверка. `setScheduledTime` уже получает `time: Date?` — проверяем на nil:

```swift
    static func setScheduledTime(_ task: DailyTask, time: Date?, in ctx: ModelContext) {
        if let time {
            task.scheduledTime = time
            task.calendarEventID = CalendarService.sync(task)
        } else {
            if let eventID = task.calendarEventID {
                CalendarService.remove(eventID: eventID)
                task.calendarEventID = nil
            }
            task.scheduledTime = nil
        }
        try? ctx.save()
    }
```

- [ ] **Шаг 3.2: Commit**

```bash
git add DailyFlow/Services/TaskService.swift
git commit -m "feat(service): integrate CalendarService into TaskService"
```

---

## Task 4: UI — AddTaskBarView с TimePicker

**Files:**
- Modify: `DailyFlow/Views/Today/AddTaskBarView.swift`

- [ ] **Шаг 4.1: Переписать AddTaskBarView**

AddTaskBarView должен принимать `onSubmit: (String, Date?) -> Void`. Кнопка clock раскрывает DatePicker только когда поле активно.

```swift
import SwiftUI

struct AddTaskBarView: View {
    @Binding var text: String
    let onSubmit: (String, Date?) -> Void
    @FocusState private var focused: Bool
    @State private var scheduledTime: Date? = nil
    @State private var showTimePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    .font(.system(size: 13))

                if focused {
                    Button {
                        showTimePicker.toggle()
                    } label: {
                        Image(systemName: scheduledTime != nil ? "clock.fill" : "clock")
                            .foregroundStyle(scheduledTime != nil ? Color.accentTeal : Color.textSecondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                if focused {
                    Rectangle()
                        .fill(Color.accentTeal)
                        .frame(height: 1)
                }
            }

            if focused && showTimePicker {
                timePickerRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(.rect)
        .onTapGesture { focused = true }
        .animation(.spring(duration: 0.25), value: showTimePicker)
        .animation(.easeInOut(duration: 0.2), value: focused)
    }

    private var timePickerRow: some View {
        HStack {
            DatePicker(
                "",
                selection: Binding(
                    get: { scheduledTime ?? Date() },
                    set: { scheduledTime = $0 }
                ),
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .accentColor(Color.accentTeal)

            if scheduledTime != nil {
                Button {
                    scheduledTime = nil
                    showTimePicker = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Haptics.tap(.light)
        onSubmit(trimmed, scheduledTime)
        text = ""
        scheduledTime = nil
        showTimePicker = false
    }
}

#Preview {
    @Previewable @State var text = ""
    AddTaskBarView(text: $text, onSubmit: { _, _ in })
        .padding(.horizontal, 16)
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
```

- [ ] **Шаг 4.2: Commit**

```bash
git add DailyFlow/Views/Today/AddTaskBarView.swift
git commit -m "feat(ui): add time picker to AddTaskBarView"
```

---

## Task 5: TodayContentView — обновить onSubmit

**Files:**
- Modify: `DailyFlow/Views/Today/TodayContentView.swift`

- [ ] **Шаг 5.1: Обновить вызов AddTaskBarView**

Найти строку в TodayContentView.swift (строка ~90):
```swift
                AddTaskBarView(
                    text: $addBarText,
                    onSubmit: { TaskService.add(title: $0, on: dateAnchor, in: ctx) }
                )
```

Заменить на:
```swift
                AddTaskBarView(
                    text: $addBarText,
                    onSubmit: { title, time in
                        TaskService.add(title: title, scheduledTime: time, on: dateAnchor, in: ctx)
                    }
                )
```

- [ ] **Шаг 5.2: Commit**

```bash
git add DailyFlow/Views/Today/TodayContentView.swift
git commit -m "feat(ui): pass scheduledTime through TodayContentView to TaskService"
```

---

## Task 6: TaskRowView — метка времени

**Files:**
- Modify: `DailyFlow/Views/Today/TaskRowView.swift`

- [ ] **Шаг 6.1: Показывать время рядом с заголовком задачи**

В `TaskRowView.body`, в ветке `else` (строки ~59–68), после `Text(task.title)` добавить отображение времени. Нужно заменить блок `else` с:

```swift
            } else {
                Text(task.title)
                    .dfBody()
                    .foregroundStyle(task.isCompleted ? Color.textSecondary : Color.textPrimary)
                    .strikethrough(task.isCompleted)
                    .opacity(task.isCompleted ? 0.5 : 1)
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.15), value: task.isCompleted)
            }
```

На:

```swift
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .dfBody()
                        .foregroundStyle(task.isCompleted ? Color.textSecondary : Color.textPrimary)
                        .strikethrough(task.isCompleted)
                        .opacity(task.isCompleted ? 0.5 : 1)
                        .lineLimit(2)
                        .animation(.easeInOut(duration: 0.15), value: task.isCompleted)

                    if let time = task.scheduledTime {
                        Text(time, format: .dateTime.hour().minute())
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
```

- [ ] **Шаг 6.2: Commit**

```bash
git add DailyFlow/Views/Today/TaskRowView.swift
git commit -m "feat(ui): show scheduledTime label in TaskRowView"
```

---

## Task 7: NSCalendarsWriteOnlyAccessUsageDescription в pbxproj

**Files:**
- Modify: `DailyFlow.xcodeproj/project.pbxproj`

- [ ] **Шаг 7.1: Добавить ключ NSCalendars в build settings DailyFlow target**

В pbxproj найти секцию `4E3818892FACD1C600DF5114 /* Debug */` (первая конфигурация DailyFlow target) и `4E38188A2FACD1C600DF5114 /* Release */`.

В каждую секцию после строки `INFOPLIST_KEY_UIUserInterfaceStyle = Dark;` добавить:

```
				INFOPLIST_KEY_NSCalendarsWriteOnlyAccessUsageDescription = "DailyFlow добавляет задачи с временем в Календарь";
```

Для Debug (`4E3818892FACD1C600DF5114`), строка с `INFOPLIST_KEY_UIUserInterfaceStyle = Dark;` — это строка 335. Добавить после неё.
Для Release (`4E38188A2FACD1C600DF5114`), аналогично строка 366.

- [ ] **Шаг 7.2: Добавить Code Sign Entitlements для DailyFlow**

Создать файл `DailyFlow/DailyFlow.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.dmitry.dailyflow</string>
	</array>
</dict>
</plist>
```

В обеих конфигурациях DailyFlow target добавить:

```
				CODE_SIGN_ENTITLEMENTS = DailyFlow/DailyFlow.entitlements;
```

- [ ] **Шаг 7.3: Commit**

```bash
git add DailyFlow/DailyFlow.entitlements DailyFlow.xcodeproj/project.pbxproj
git commit -m "feat(config): add NSCalendars plist key and App Group entitlements to DailyFlow"
```

---

## Task 8: Widget Extension target в pbxproj

**Files:**
- Create: `DailyFlowWidgets/` (новая папка)
- Create: `DailyFlowWidgets/DailyFlowWidgets.entitlements`
- Modify: `DailyFlow.xcodeproj/project.pbxproj`
- Modify: `DailyFlow/Widgets/DailyFlowWidgets.swift` (опустошить)

Новые UUID объектов (фиксированные, не пересекаются с существующими `4E3818...`):

| Объект | UUID |
|---|---|
| DailyFlowWidgets.appex (FileRef) | `4E38FF012FACD1C400DF5114` |
| DailyFlowWidgets folder (SyncGroup) | `4E38FF022FACD1C400DF5114` |
| Widget Sources phase | `4E38FF032FACD1C400DF5114` |
| Widget Frameworks phase | `4E38FF042FACD1C400DF5114` |
| Widget Resources phase | `4E38FF052FACD1C400DF5114` |
| CopyFiles phase (в main app) | `4E38FF062FACD1C400DF5114` |
| Widget PBXNativeTarget | `4E38FF072FACD1C400DF5114` |
| Widget ContainerItemProxy | `4E38FF082FACD1C400DF5114` |
| Widget TargetDependency | `4E38FF092FACD1C400DF5114` |
| Widget Debug XCBuildConfig | `4E38FF0A2FACD1C400DF5114` |
| Widget Release XCBuildConfig | `4E38FF0B2FACD1C400DF5114` |
| Widget XCConfigurationList | `4E38FF0C2FACD1C400DF5114` |
| CopyFiles build file | `4E38FF0D2FACD1C400DF5114` |

- [ ] **Шаг 8.1: Создать DailyFlowWidgets/DailyFlowWidgets.entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.dmitry.dailyflow</string>
	</array>
</dict>
</plist>
```

- [ ] **Шаг 8.2: Опустошить DailyFlow/Widgets/DailyFlowWidgets.swift**

```swift
// Widget implementation is in DailyFlowWidgets target
```

- [ ] **Шаг 8.3: Добавить объекты в pbxproj**

Вставить в `project.pbxproj` после `/* End PBXFileReference section */`:

```
/* Begin PBXBuildFile section */
		4E38FF0D2FACD1C400DF5114 /* DailyFlowWidgets.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = 4E38FF012FACD1C400DF5114 /* DailyFlowWidgets.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
/* End PBXBuildFile section */
```

Добавить в `/* Begin PBXFileReference section */` (после строки `4E3818742FACD1C600DF5114`):

```
		4E38FF012FACD1C400DF5114 /* DailyFlowWidgets.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = DailyFlowWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR; };
```

Добавить в `/* Begin PBXFileSystemSynchronizedRootGroup section */` (после строки `4E3818772FACD1C600DF5114`):

```
		4E38FF022FACD1C400DF5114 /* DailyFlowWidgets */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = DailyFlowWidgets;
			sourceTree = "<group>";
		};
```

Добавить `4E38FF012FACD1C400DF5114 /* DailyFlowWidgets.appex */,` в Products group (`4E3818662FACD1C400DF5114`) список children.

Добавить `4E38FF022FACD1C400DF5114 /* DailyFlowWidgets */,` в main group (`4E38185C2FACD1C400DF5114`) список children.

Добавить в `/* Begin PBXCopyFilesBuildPhase section */` (новая секция):

```
/* Begin PBXCopyFilesBuildPhase section */
		4E38FF062FACD1C400DF5114 /* Embed Foundation Extensions */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				4E38FF0D2FACD1C400DF5114 /* DailyFlowWidgets.appex in Embed Foundation Extensions */,
			);
			name = "Embed Foundation Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXCopyFilesBuildPhase section */
```

Добавить в `/* Begin PBXFrameworksBuildPhase section */`:

```
		4E38FF042FACD1C400DF5114 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

Добавить в `/* Begin PBXResourcesBuildPhase section */`:

```
		4E38FF052FACD1C400DF5114 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

Добавить в `/* Begin PBXSourcesBuildPhase section */`:

```
		4E38FF032FACD1C400DF5114 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

Добавить в `/* Begin PBXNativeTarget section */` новый target:

```
		4E38FF072FACD1C400DF5114 /* DailyFlowWidgets */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 4E38FF0C2FACD1C400DF5114 /* Build configuration list for PBXNativeTarget "DailyFlowWidgets" */;
			buildPhases = (
				4E38FF032FACD1C400DF5114 /* Sources */,
				4E38FF042FACD1C400DF5114 /* Frameworks */,
				4E38FF052FACD1C400DF5114 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				4E38FF022FACD1C400DF5114 /* DailyFlowWidgets */,
			);
			name = DailyFlowWidgets;
			packageProductDependencies = (
			);
			productName = DailyFlowWidgets;
			productReference = 4E38FF012FACD1C400DF5114 /* DailyFlowWidgets.appex */;
			productType = "com.apple.product-type.app-extension";
		};
```

Обновить `4E3818642FACD1C400DF5114 /* DailyFlow */` PBXNativeTarget:
- Добавить `4E38FF062FACD1C400DF5114 /* Embed Foundation Extensions */,` в `buildPhases`
- Добавить `4E38FF092FACD1C400DF5114 /* PBXTargetDependency */,` в `dependencies`

Добавить в `/* Begin PBXContainerItemProxy section */`:

```
		4E38FF082FACD1C400DF5114 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 4E38185D2FACD1C400DF5114 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 4E38FF072FACD1C400DF5114;
			remoteInfo = DailyFlowWidgets;
		};
```

Добавить в `/* Begin PBXTargetDependency section */`:

```
		4E38FF092FACD1C400DF5114 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 4E38FF072FACD1C400DF5114 /* DailyFlowWidgets */;
			targetProxy = 4E38FF082FACD1C400DF5114 /* PBXContainerItemProxy */;
		};
```

Добавить build configurations для виджета в `/* Begin XCBuildConfiguration section */`:

```
		4E38FF0A2FACD1C400DF5114 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_ENTITLEMENTS = DailyFlowWidgets/DailyFlowWidgets.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = DailyFlowWidgets;
				INFOPLIST_KEY_NSExtension_NSExtensionPointIdentifier = com.apple.widgetkit-extension;
				INFOPLIST_KEY_UIUserInterfaceStyle = Dark;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.dmitry.DailyFlow.Widgets;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1";
			};
			name = Debug;
		};
		4E38FF0B2FACD1C400DF5114 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_ENTITLEMENTS = DailyFlowWidgets/DailyFlowWidgets.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = DailyFlowWidgets;
				INFOPLIST_KEY_NSExtension_NSExtensionPointIdentifier = com.apple.widgetkit-extension;
				INFOPLIST_KEY_UIUserInterfaceStyle = Dark;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.dmitry.DailyFlow.Widgets;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1";
			};
			name = Release;
		};
```

Добавить конфигурационный список для виджета в `/* Begin XCConfigurationList section */`:

```
		4E38FF0C2FACD1C400DF5114 /* Build configuration list for PBXNativeTarget "DailyFlowWidgets" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				4E38FF0A2FACD1C400DF5114 /* Debug */,
				4E38FF0B2FACD1C400DF5114 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
```

Обновить `PBXProject` (4E38185D2FACD1C400DF5114):
- В `targets` добавить `4E38FF072FACD1C400DF5114 /* DailyFlowWidgets */,`
- В `TargetAttributes` добавить:
  ```
  4E38FF072FACD1C400DF5114 = {
      CreatedOnToolsVersion = 26.4;
  };
  ```

- [ ] **Шаг 8.4: Commit**

```bash
git add DailyFlowWidgets/ DailyFlow/Widgets/DailyFlowWidgets.swift DailyFlowWidgets/DailyFlowWidgets.entitlements DailyFlow.xcodeproj/project.pbxproj
git commit -m "feat(project): add DailyFlowWidgets extension target to pbxproj"
```

---

## Task 9: ToggleTaskIntent

**Files:**
- Create: `DailyFlowWidgets/ToggleTaskIntent.swift`

- [ ] **Шаг 9.1: Создать ToggleTaskIntent.swift**

```swift
import AppIntents
import SwiftData
import WidgetKit

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        let config = ModelConfiguration(
            groupContainer: .identifier("group.com.dmitry.dailyflow")
        )
        let container = try ModelContainer(for: DailyTask.self, configurations: config)
        let ctx = ModelContext(container)

        let targetID = UUID(uuidString: taskID)
        let pred = #Predicate<DailyTask> { $0.id == targetID }
        if let task = try ctx.fetch(FetchDescriptor(predicate: pred)).first {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? .now : nil
            try ctx.save()
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

Заметка о #Predicate: в Swift, `$0.id == targetID` где `targetID` — `UUID?` не скомпилируется напрямую. Нужен `unwrap`:

```swift
    func perform() async throws -> some IntentResult {
        let config = ModelConfiguration(
            groupContainer: .identifier("group.com.dmitry.dailyflow")
        )
        let container = try ModelContainer(for: DailyTask.self, configurations: config)
        let ctx = ModelContext(container)

        guard let targetID = UUID(uuidString: taskID) else {
            return .result()
        }
        let pred = #Predicate<DailyTask> { $0.id == targetID }
        if let task = try ctx.fetch(FetchDescriptor(predicate: pred)).first {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? .now : nil
            try ctx.save()
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
```

- [ ] **Шаг 9.2: Commit**

```bash
git add DailyFlowWidgets/ToggleTaskIntent.swift
git commit -m "feat(widget): add ToggleTaskIntent AppIntent"
```

---

## Task 10: DailyFlowWidgets — реализация виджета

**Files:**
- Create: `DailyFlowWidgets/DailyFlowWidgets.swift`

- [ ] **Шаг 10.1: Создать полную реализацию виджета**

```swift
import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Entry

struct DailyFlowEntry: TimelineEntry {
    let date: Date
    let tasks: [DailyTask]
}

// MARK: - Provider

struct DailyFlowWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyFlowEntry {
        DailyFlowEntry(date: .now, tasks: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyFlowEntry) -> Void) {
        completion(DailyFlowEntry(date: .now, tasks: fetchTodayTasks()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyFlowEntry>) -> Void) {
        let tasks = fetchTodayTasks()
        let entry = DailyFlowEntry(date: .now, tasks: tasks)
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func fetchTodayTasks() -> [DailyTask] {
        guard let container = try? ModelContainer(
            for: DailyTask.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier("group.com.dmitry.dailyflow")
            )
        ) else { return [] }

        let ctx = ModelContext(container)
        let today = Calendar.current.startOfDay(for: .now)
        let pred = #Predicate<DailyTask> { $0.date == today }
        let descriptor = FetchDescriptor(predicate: pred, sortBy: [SortDescriptor(\.createdAt)])
        return (try? ctx.fetch(descriptor)) ?? []
    }
}

// MARK: - Colors (зеркало токенов, App Extensions не имеют доступа к основному модулю)

private extension Color {
    static let bgPrimary = Color(red: 0.051, green: 0.051, blue: 0.051)
    static let bgCard = Color(red: 0.102, green: 0.102, blue: 0.102)
    static let accentTeal = Color(red: 0.176, green: 0.831, blue: 0.627)
    static let textPrimary = Color(red: 0.949, green: 0.949, blue: 0.949)
    static let textSecondary = Color(red: 0.533, green: 0.533, blue: 0.533)
}

// MARK: - EntryView

struct DailyFlowWidgetEntryView: View {
    var entry: DailyFlowEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("СЕГОДНЯ")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.5)

            if entry.tasks.isEmpty {
                Text("Нет задач")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(entry.tasks.prefix(5)) { task in
                    Button(intent: ToggleTaskIntent(taskID: task.id.uuidString)) {
                        HStack(spacing: 6) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(task.isCompleted ? Color.accentTeal : Color.textSecondary)
                            Text(task.title)
                                .font(.system(size: 12))
                                .foregroundStyle(task.isCompleted ? Color.textSecondary : Color.textPrimary)
                                .strikethrough(task.isCompleted)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bgPrimary)
    }
}

// MARK: - Widget

@main
struct DailyFlowWidget: Widget {
    let kind = "DailyFlowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyFlowWidgetProvider()) { entry in
            DailyFlowWidgetEntryView(entry: entry)
                .containerBackground(Color.bgPrimary, for: .widget)
        }
        .configurationDisplayName("DailyFlow")
        .description("Задачи на сегодня")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

- [ ] **Шаг 10.2: Commit**

```bash
git add DailyFlowWidgets/DailyFlowWidgets.swift
git commit -m "feat(widget): implement DailyFlowWidget with interactive task toggle"
```

---

## Task 11: Запустить билд и устранить ошибки

- [ ] **Шаг 11.1: Запустить /build**

```bash
cd /path/to/project && xcodebuild -project DailyFlow.xcodeproj -scheme DailyFlow -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | xcbeautify
```

Ожидаемый результат: `Build Succeeded` без ошибок.

Частые проблемы и решения:
- **`CalendarService` not found в TaskService**: убедиться что файл в папке DailyFlow/ (синхронизируется автоматически)
- **`#Predicate` с Optional UUID**: использовать `guard let` перед предикатом (уже в плане)
- **`INFOPLIST_KEY_NSExtension...`**: в pbxproj это не работает так, нужен отдельный Info.plist для виджета extension — см. шаг 11.2
- **Widget не компилируется из-за отсутствия @main в приложении**: OK, у виджета свой @main

- [ ] **Шаг 11.2: Если нужен отдельный Info.plist для виджета**

Если `GENERATE_INFOPLIST_FILE` с `INFOPLIST_KEY_NSExtension_NSExtensionPointIdentifier` не работает для extension target, создать `DailyFlowWidgets/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
```

И в build settings виджета заменить `GENERATE_INFOPLIST_FILE = YES` на:

```
INFOPLIST_FILE = DailyFlowWidgets/Info.plist;
```

- [ ] **Шаг 11.3: Commit**

```bash
git add .
git commit -m "fix(build): resolve build errors from calendar and widget integration"
```

---

## Task 12: Запросить доступ к Календарю при запуске

**Files:**
- Modify: `DailyFlow/App/DailyFlowApp.swift`

- [ ] **Шаг 12.1: Прочитать DailyFlowApp.swift**

Прочитать файл и добавить вызов `CalendarService.requestAccess()` при запуске в `.task` или `.onAppear`.

- [ ] **Шаг 12.2: Добавить запрос доступа**

После `@main` View, в основном `.body` или первом экране, добавить:

```swift
.task {
    await CalendarService.requestAccess()
}
```

- [ ] **Шаг 12.3: Commit**

```bash
git add DailyFlow/App/DailyFlowApp.swift
git commit -m "feat(app): request calendar access on launch"
```

---

## Task 13: Финальная верификация

- [ ] **Шаг 13.1: Build 0 ошибок, 0 warnings**

```bash
xcodebuild -project DailyFlow.xcodeproj -scheme DailyFlow -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | xcbeautify
```

- [ ] **Шаг 13.2: Запустить тесты**

```bash
xcodebuild -project DailyFlow.xcodeproj -scheme DailyFlowTests -destination "platform=iOS Simulator,name=iPhone 16" test 2>&1 | xcbeautify
```

Ожидаемый результат: 53 теста проходят (существующие).

- [ ] **Шаг 13.3: Lint**

```bash
swiftlint lint --path DailyFlow/
```

Ожидаемый результат: 0 violations.

- [ ] **Шаг 13.4: Обновить CLAUDE.md**

В CLAUDE.md:
- Добавить `CalendarService.swift` и `ToggleTaskIntent.swift` в раздел Services/Widgets
- Обновить статус: "Phase 5 началась. Calendar + Widget интеграция."
- Добавить в Выполненные фичи:
  - [x] Интеграция с Календарём (EventKit)
  - [x] Интерактивные виджеты (WidgetKit + AppIntents)

- [ ] **Шаг 13.5: Final commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md — calendar and widget integration complete"
```
