---
description: Запустить iPhone Simulator (iPhone 16 Pro) и (опционально) открыть проект в Xcode
---

Подними iOS Simulator с iPhone 16 Pro для тестирования DailyFlow.

Шаги:
1. Получи UDID iPhone 16 Pro:
   ```bash
   xcrun simctl list devices available | grep "iPhone 16 Pro" | head -1
   ```
2. Загрузись в этот симулятор:
   ```bash
   open -a Simulator --args -CurrentDeviceUDID <UDID>
   ```
3. Подожди 2 секунды, затем убедись что симулятор поднялся:
   ```bash
   xcrun simctl list devices booted
   ```
4. Если пользователь попросит — открой Xcode-проект:
   ```bash
   open DailyFlow.xcodeproj
   ```

Если `iPhone 16 Pro` отсутствует в списке — предложи список доступных и спроси, какой использовать.
