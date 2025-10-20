# Fix для list_apps инструмента

## Проблема
Агент Claude говорил, что у него нет возможности получить список установленных приложений на симуляторе.

## Диагностика
При проверке было обнаружено, что:
- ✅ Инструмент `list_apps` существует и правильно зарегистрирован в TypeScript MCP сервере
- ✅ Инструмент правильно экспортирован в Swift (`SimulatorTools.swift`)
- ✅ Инструмент упоминается в system prompt
- ✅ MCP сервер корректно отвечает при прямом вызове
- ✅ Команда `xcrun simctl listapps` работает

## Решение

### 1. Улучшен формат вывода list_apps

**Файл:** `mcp-ios-simulator-server/src/index.ts` (строки 219-296)

**До:**
```
Возвращался сырой вывод property list - нечитаемый формат с множеством технической информации
```

**После:**
```
📱 Установленные приложения на симуляторе "iPhone 15 Pro":

👤 ПОЛЬЗОВАТЕЛЬСКИЕ ПРИЛОЖЕНИЯ (1):
  • HLSCatalog
    Bundle ID: com.example.apple-samplecode.HLSCatalog

🍎 СИСТЕМНЫЕ ПРИЛОЖЕНИЯ (17):
  • Safari
    Bundle ID: com.apple.mobilesafari
  • Photos
    Bundle ID: com.apple.mobileslideshow
  ...
```

### 2. Улучшен system prompt

**Файл:** `AIAdventChatV2/ViewModels/ChatViewModel.swift` (строки 476-491)

**Изменения:**
- Добавлена явная фраза "показывает ВСЕ установленные приложения на симуляторе"
- Добавлена строка "ВАЖНО: У вас ЕСТЬ возможность получить список установленных приложений через инструмент list_apps"
- Добавлена фраза "показать список приложений" в список примеров использования

### 3. Добавлено логирование

В функцию `getAppInfo` добавлено подробное логирование:
- 📋 Получаю список приложений
- ✅ Найден симулятор
- 🔍 Выполняю команду
- 📊 Парсю результат
- ✅ Найдено приложений

## Тестирование

### Прямой тест MCP сервера:
```bash
cd /Users/sergeymarkov/Documents/PetProject/AIAdventChatV2/mcp-ios-simulator-server
node test_list_apps.mjs
```

**Результат:** ✅ Работает корректно

### Сборка приложения:
```bash
cd /Users/sergeymarkov/Documents/PetProject/AIAdventChatV2
xcodebuild -project AIAdventChatV2.xcodeproj -scheme AIAdventChatV2 -configuration Debug build
```

**Результат:** ✅ BUILD SUCCEEDED

## Следующие шаги для пользователя

1. **Перезапустить приложение AIAdventChatV2** полностью (Quit + запустить заново)
2. **Протестировать в чате:**
   - "Покажи список приложений на iPhone 15 Pro"
   - "Какие приложения установлены на симуляторе?"
   - "Что установлено на iPhone 15 Pro?"

3. **Проверить логи в консоли Xcode:**
   - При вызове инструмента должно быть: "🔧 SimulatorTools.executeTool вызван с name: 'list_apps'"
   - В stderr MCP сервера должно быть: "📋 Получаю список приложений для: ..."

## Файлы изменены

1. `/Users/sergeymarkov/Documents/PetProject/AIAdventChatV2/mcp-ios-simulator-server/src/index.ts`
   - Строки 219-296: Полностью переписана функция `getAppInfo()`
   - Добавлен парсинг property list
   - Форматированный вывод

2. `/Users/sergeymarkov/Documents/PetProject/AIAdventChatV2/AIAdventChatV2/ViewModels/ChatViewModel.swift`
   - Строки 486-490: Улучшено описание инструмента list_apps в system prompt

## Технические детали

### Как работает парсинг:

1. Получаем вывод `xcrun simctl listapps UDID`
2. Извлекаем все Bundle IDs через regex: `/"([^"]+)"\s*=/g`
3. Для каждого Bundle ID находим его блок данных
4. Извлекаем `CFBundleDisplayName` (человеко-читаемое имя)
5. Извлекаем `ApplicationType` (System или User)
6. Разделяем на две группы: пользовательские и системные
7. Форматируем в читаемый вид

### Пример сырого вывода:
```
"com.apple.mobilesafari" = {
    ApplicationType = System;
    CFBundleDisplayName = Safari;
    CFBundleIdentifier = "com.apple.mobilesafari";
    ...
};
```

### Пример обработанного вывода:
```
  • Safari
    Bundle ID: com.apple.mobilesafari
```

## Статус: ✅ ГОТОВО

Все изменения внесены и протестированы. MCP сервер работает корректно. Приложение успешно собрано.
