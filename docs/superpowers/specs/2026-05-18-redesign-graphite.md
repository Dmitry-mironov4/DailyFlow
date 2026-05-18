# DailyFlow — Редизайн: Graphite + White
*Дата: 2026-05-18 | Статус: спецификация*

---

## Концепция

**Graphite + White** — монохромный минимализм без цветовых акцентов.
Единственный акцент — белый (`#F5F5F5`) для CTA и фокуса. Зелёный (`#4ADE80`) появляется **только** в момент выполнения задачи/привычки и исчезает. Никакого декора, никаких цветов для ради цвета.

Ближайшие аналоги: Things 3 Dark, Bear (dark), Obsidian, Reeder 5.

---

## Цветовая палитра

### Фоны (elevation-система)

| Токен | HEX | Использование |
|---|---|---|
| `bg.primary` | `#111214` | Фон экрана |
| `bg.card` | `#1A1C1F` | Фон карточки (elevation 1) |
| `bg.elevated` | `#212427` | Модалки, активные элементы (elevation 2) |
| `bg.input` | `#1A1C1F` | Фон TextEditor, TextField |

### Разделители

| Токен | HEX / rgba | Использование |
|---|---|---|
| `separator` | `#2C2F33` | 1px линии между элементами |
| `border.card` | `rgba(255,255,255,0.06)` | Тонкий бордер карточки |

### Акценты

| Токен | HEX | Использование |
|---|---|---|
| `accent.white` | `#F5F5F5` | CTA, focus task, активный чекбокс, selected state |
| `accent.done` | `#4ADE80` | **Только** состояние "выполнено" — мгновенно, не постоянно |
| `accent.destructive` | `#F87171` | Удаление, ошибки |

### Текст

| Токен | HEX / rgba | Использование |
|---|---|---|
| `text.primary` | `#DCDCDC` | Основной текст |
| `text.secondary` | `#808080` | Метаданные, дата, стрик |
| `text.ghost` | `#464646` | Плейсхолдеры |
| `text.inverted` | `#111214` | Текст на белом фоне (кнопки) |

### Запрещено
- Любые градиенты
- Тени (`shadow`)
- Цветные карточки (старые `accentTeal`, `accentAmber`, `accentPurple` — удалить)
- Цветные иконки в таббаре (только система: selected = white, unselected = gray)

---

## Типографика (SF Pro, без изменений в размерах)

| Токен | Размер | Вес | Доп. |
|---|---|---|---|
| `.dfTitle` | 21pt | `.medium` | — |
| `.dfBody` | 15pt | `.regular` | — |
| `.dfCaption` | 11pt | `.regular` | letter-spacing 0.5pt, ALL CAPS |
| `.dfStat` | 28pt | `.semibold` | KPI-цифры на инсайтах |
| `.dfLabel` | 13pt | `.regular` | Метки |

Единственное изменение vs текущего: `.dfTitle` теперь `text.primary` (#DCDCDC), а не тёплый кремовый.

---

## Компоненты

### Карточка (`.dfCard`)

```
background: bg.card (#1A1C1F)
cornerRadius: 12pt
padding: 16pt horizontal, 14pt vertical
border: 1px, rgba(255,255,255,0.06)
```

Акцентная карточка (`.dfAccentCard`) — используется ТОЛЬКО для Focus Task:
```
background: accent.white (#F5F5F5)
text: text.inverted (#111214)
cornerRadius: 12pt
padding: 16pt horizontal, 14pt vertical
```

### Чекбокс

Невыполненная задача:
```
circle, 20pt
stroke: separator (#2C2F33), 1.5pt
fill: clear
```

При выполнении (transient, 0.3s):
```
fill: accent.done (#4ADE80)
SF Symbol: checkmark, white
```

После анимации (completed):
```
fill: bg.elevated (#212427)
SF Symbol: checkmark, text.secondary (#808080)
```
Идея: зелёный только как мгновенная вспышка подтверждения, потом уходит в серое.

### Кнопка "Добавить" (ghost → inline)

Ghost:
```
label: "+ Задача"
color: text.ghost (#464646)
background: clear
```

Active (inline TextField):
```
background: bg.elevated (#212427)
cornerRadius: 8pt
tint: accent.white
```

### Строка привычки

Невыполненная:
```
background: bg.card
left: цветная точка → УБРАТЬ. Вместо — пустой кружок 8pt, stroke separator
```

Выполненная:
```
left: кружок 8pt, fill accent.done (#4ADE80) → через 2с fade to text.secondary
```

PixelGrid: 7 квадратов 28×28pt
- inactive: `bg.elevated (#212427)`
- active: `accent.white (#F5F5F5)` с opacity 0.9

### MoodPicker (5 тайлов)

Все тайлы одинакового цвета `bg.card`. Selected — `bg.elevated` с бордером `accent.white` 1.5pt.
Никаких emoji-цветов на тайлах — только цифра + текст.

Цвета настроения **убрать совсем** — они противоречат graphite-концепции.

### TabBar

```
background: bg.card (#1A1C1F)
selected icon: accent.white (#F5F5F5)
unselected icon: text.ghost (#464646)
separator top: separator (#2C2F33), 1px
```

---

## Экраны — изменения

### Today

- FocusCardView: белая карточка (`.dfAccentCard`) с тёмным текстом — визуальный якорь экрана
- Обычные задачи: серые строки на `bg.primary`, без карточки-обёртки (просто List с bg.primary)
- Выполненные задачи: strikethrough, `text.secondary`, чекбокс серый
- RolloverBanner: `bg.elevated`, бордер `separator`, текст `text.secondary`

### Habits

- HabitCard: без цветных точек. Название + стрик + PixelGrid
- PixelGrid: inactive = `bg.elevated`, active = `accent.white`
- Стрик-число: `text.secondary` + 🔥 emoji — убрать emoji, оставить просто число и "дн."
- AddHabitSheet: убрать ColorPicker совсем (раз нет цветов)

### Journal

- MoodPicker: 5 одинаковых тайлов `bg.card`, selected = бордер `accent.white`
- Текстовый редактор: `bg.primary`, плейсхолдер `text.ghost`
- Заголовок даты: `text.secondary`, `.dfCaption`

### Insights

- MetricCard: число `.dfStat` цвет `text.primary`, label `text.secondary`
- Тренд ↑↓: вместо цветных стрелок — только `↑`/`↓` цвет `text.secondary`
- MoodChart: BarMark цвет `accent.white` с opacity 0.7–1.0 (высота бара = интенсивность opacity)
- StreakRow: порядковый номер `text.ghost`, название `text.primary`, стрик `text.secondary`

---

## Что удалить из ColorExtensions

Убрать:
- `accentTeal` (#D4882A)
- `accentAmber` (#E8C46A)
- `accentPurple` (#B8622A)
- `bgPixelInactive` (#362A14)
- `textPrimary` (#F0E8D8) — заменить на `#DCDCDC`
- `textSecondary` (#8A7860) — заменить на `#808080`
- `textGhost` (#5E4E38) — заменить на `#464646`
- `bgPrimary` (#0D0A05) — заменить на `#111214`
- `bgCard` (#1C1409) — заменить на `#1A1C1F`

Добавить:
- `bgElevated` (#212427)
- `separator` (#2C2F33)
- `borderCard` (rgba white 0.06)
- `accentWhite` (#F5F5F5)
- `accentDone` (#4ADE80)
- `accentDestructive` (#F87171)
- `textInverted` (#111214)
- `moodColor(for:)` — убрать совсем

---

## Анимации

Принцип: анимации только функциональные, не декоративные.

| Действие | Анимация |
|---|---|
| Закрытие задачи | Чекбокс: fill → #4ADE80 (0.15s easeOut), через 0.3s fade to серый |
| Strikethrough текста | opacity текста 1.0 → 0.4, strikethrough линия 0.2s |
| Toggle привычки | PixelGrid квадрат: scale 0.8 → 1.0 (0.2s spring) |
| Focus Task появление | Вся карточка: scale 0.97 → 1.0, opacity 0 → 1 (0.25s) |
| Добавление задачи | Row insert сверху: slide + fade (системный SwiftUI .transition) |

---

## Пример кода ColorExtensions (новый)

```swift
extension Color {
    // Backgrounds
    static let bgPrimary   = Color(hex: 0x111214)
    static let bgCard      = Color(hex: 0x1A1C1F)
    static let bgElevated  = Color(hex: 0x212427)

    // Separators
    static let separator   = Color(hex: 0x2C2F33)
    static let borderCard  = Color.white.opacity(0.06)

    // Accents
    static let accentWhite       = Color(hex: 0xF5F5F5)
    static let accentDone        = Color(hex: 0x4ADE80)
    static let accentDestructive = Color(hex: 0xF87171)

    // Text
    static let textPrimary   = Color(hex: 0xDCDCDC)
    static let textSecondary = Color(hex: 0x808080)
    static let textGhost     = Color(hex: 0x464646)
    static let textInverted  = Color(hex: 0x111214)
}
```
