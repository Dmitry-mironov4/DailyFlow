---
description: Сборка DailyFlow для iPhone-симулятора с читаемым выводом xcbeautify
---

Собери проект DailyFlow для симулятора iPhone 16 Pro в конфигурации Debug.

Шаги:
1. Если файл `DailyFlow.xcodeproj` ещё не создан — сообщи об этом и предложи создать его через Xcode (`File → New → Project → iOS App`), не пытайся симулировать сборку.
2. Если проект существует, выполни:
   ```bash
   set -o pipefail && xcodebuild \
     -project DailyFlow.xcodeproj \
     -scheme DailyFlow \
     -configuration Debug \
     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
     build | xcbeautify
   ```
3. Если есть ошибки — выведи их кратким списком (файл:строка — сообщение), без лишнего шума.
4. Если сборка успешна — выведи только `✅ build ok` и время сборки.

Никогда не коммить изменения автоматически после сборки.
