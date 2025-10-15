# 🔌 Исправление потери соединения MCP

## 🐛 Проблема

**Симптом:**
- ✅ Первое сообщение от погодного агента приходит успешно
- ❌ Через 2 минуты при втором выполнении ошибка:
  ```
  ❌ Ошибка выполнения задачи: Internal error: Client connection not initialized
  ```

**Причина:** MCP клиент теряет соединение после первого использования, но флаг `isConnected` остаётся `true`, поэтому не происходит переподключения.

---

## 🔍 Анализ проблемы

### Что происходило:

1. **Первое выполнение (t=0):**
   ```
   mcpService.connect() → ✅ Успешно
   mcpService.isConnected = true
   mcpService.callTool() → ✅ Работает
   ```

2. **Второе выполнение (t=2 минуты):**
   ```
   mcpService.isConnected = true ← Всё ещё true!
   Не переподключаемся (isConnected == true)
   mcpService.callTool() → ❌ "Client connection not initialized"
   ```

### Почему соединение теряется?

Возможные причины:
1. **MCP Server процесс умер** - Node.js процесс завершился
2. **Stdio pipes закрылись** - stdin/stdout pipes были закрыты
3. **Client был disconnected** - MCP Client внутри SDK отключился
4. **Timeout** - Соединение закрылось по таймауту

Но флаг `isConnected` в `MCPService` обновляется только при:
- Успешном `connect()` → `true`
- Явном `disconnect()` → `false`
- Ошибке при `connect()` → `false`

При **потере соединения во время работы** флаг не обновляется!

---

## ✅ Решение

### Стратегия: Try-Catch с автоматическим переподключением

Вместо того чтобы полагаться на флаг `isConnected`, всегда пытаемся выполнить инструмент и обрабатываем ошибку:

```swift
do {
    // Пытаемся выполнить инструмент
    let result = try await mcpService.callTool(...)
    return result

} catch {
    // Если ошибка связана с потерей соединения
    if error.localizedDescription.contains("not initialized") {
        // 1. Отключаемся от старого соединения
        await mcpService.disconnect()

        // 2. Переподключаемся
        mcpService.initializeClient()
        try await mcpService.connect(...)

        // 3. Повторяем попытку
        let result = try await mcpService.callTool(...)
        return result
    }

    throw error
}
```

---

## 📝 Детали реализации

### Файл: `PeriodicTaskService.swift`

#### Метод `executeMCPTool()` (строки 141-208)

**Основная логика:**

```swift
private func executeMCPTool(
    action: String,
    parameters: [String: String]
) async throws -> String {
    // 1. Проверяем API ключ
    guard ProcessInfo.processInfo.environment["OPENWEATHER_API_KEY"] != nil else {
        throw NSError(...)
    }

    do {
        // 2. Инициализируем клиент
        mcpService.initializeClient()

        // 3. Подключаемся если не подключены
        if !mcpService.isConnected {
            print("🔌 Подключаюсь к MCP Weather Server...")
            try await mcpService.connect(serverCommand: ["node", weatherServerPath])
            print("✅ Подключён к MCP Weather Server")
        }

        // 4. Вызываем инструмент
        print("📞 Вызываю MCP tool: \(action) с параметрами: \(parameters)")
        let arguments = parameters.mapValues { MCP.Value.string($0) }
        let result = try await mcpService.callTool(
            name: action,
            arguments: arguments
        )

        // 5. Возвращаем результат
        return extractText(from: result.content)

    } catch {
        // 6. Обработка ошибки потери соединения
        if error.localizedDescription.contains("Client connection not initialized") ||
           error.localizedDescription.contains("not initialized") {

            print("⚠️ Соединение потеряно: \(error.localizedDescription)")
            print("🔄 Пробую переподключиться...")

            // 7. ВАЖНО: Отключаемся от старого соединения
            await mcpService.disconnect()

            // 8. Переподключаемся
            mcpService.initializeClient()
            try await mcpService.connect(serverCommand: ["node", weatherServerPath])
            print("✅ Переподключился к MCP Weather Server")

            // 9. Повторяем попытку
            print("🔄 Повторяю вызов MCP tool: \(action)")
            let arguments = parameters.mapValues { MCP.Value.string($0) }
            let result = try await mcpService.callTool(
                name: action,
                arguments: arguments
            )

            return extractText(from: result.content)
        }

        // 10. Другая ошибка - пробрасываем
        print("❌ Ошибка MCP tool: \(error.localizedDescription)")
        throw error
    }
}
```

---

## 🔑 Ключевые изменения

### 1. **Добавлена проверка текста ошибки**

```swift
if error.localizedDescription.contains("not initialized")
```

Проверяем конкретный текст ошибки, чтобы определить потерю соединения.

### 2. **Явный disconnect перед reconnect**

```swift
await mcpService.disconnect()
```

**ВАЖНО!** Это гарантирует, что:
- Старый процесс сервера будет остановлен
- Старые pipes будут закрыты
- Флаг `isConnected` сбросится в `false`
- Ресурсы будут освобождены

Без этого могут остаться "зомби" процессы или locked resources.

### 3. **Полный цикл переподключения**

```swift
mcpService.initializeClient()  // Новый клиент
try await mcpService.connect() // Новое соединение
```

Создаём полностью новый клиент и соединение.

### 4. **Retry логика**

После переподключения повторяем **тот же** вызов инструмента с теми же параметрами.

### 5. **Подробное логирование**

Каждый шаг логируется для отладки:
- 🔌 Подключение
- 📞 Вызов инструмента
- ⚠️ Потеря соединения
- 🔄 Переподключение
- ✅ Успех
- ❌ Ошибка

---

## 🧪 Как тестировать

### 1. Запустите приложение с консолью

В Xcode: Window → Show Debug Area (⇧⌘Y)

### 2. Создайте периодическую задачу

```
Присылай погоду в Москве каждые 2 минуты
```

### 3. Наблюдайте логи

**Первое выполнение (сразу):**
```
⏰ Планирую задачу [UUID] с интервалом 120.0 секунд
📋 Начинаю выполнение задачи [UUID]
🔧 Вызываю MCP tool: get_weather_summary
🔌 Подключаюсь к MCP Weather Server...
✅ Подключён к MCP Weather Server
📞 Вызываю MCP tool: get_weather_summary с параметрами: ["city": "Москва"]
✅ MCP tool вернул результат: 🌤️ Погода в Москве...
💬 Добавляю результат в чат
✅ Задача успешно выполнена
```

**Второе выполнение (через 2 минуты):**

**Если соединение потеряно:**
```
⏰ Timer сработал для задачи [UUID]
📋 Начинаю выполнение задачи [UUID]
🔧 Вызываю MCP tool: get_weather_summary
📞 Вызываю MCP tool: get_weather_summary с параметрами: ["city": "Москва"]
⚠️ Соединение потеряно: Internal error: Client connection not initialized
🔄 Пробую переподключиться...
🔌 Подключаюсь к MCP Weather Server...
✅ Подключён к MCP Weather Server
✅ Переподключился к MCP Weather Server
🔄 Повторяю вызов MCP tool: get_weather_summary
✅ MCP tool вернул результат: 🌤️ Погода в Москве...
💬 Добавляю результат в чат
✅ Задача успешно выполнена
```

**Если соединение сохранилось:**
```
⏰ Timer сработал для задачи [UUID]
📋 Начинаю выполнение задачи [UUID]
🔧 Вызываю MCP tool: get_weather_summary
📞 Вызываю MCP tool: get_weather_summary с параметрами: ["city": "Москва"]
✅ MCP tool вернул результат: 🌤️ Погода в Москве...
💬 Добавляю результат в чат
✅ Задача успешно выполнена
```

### 4. Проверьте чат

Каждые 2 минуты должно появляться новое сообщение:

```
🤖 Погодный агент • 22:45 • Москва

🌤️ Погода в Москве:
• Температура: +15°C
...
```

---

## 🎯 Результат

### До исправления:
- ✅ Первое сообщение приходит
- ❌ Второе сообщение: ошибка "Client connection not initialized"
- ❌ Все последующие сообщения: та же ошибка

### После исправления:
- ✅ Первое сообщение приходит
- ✅ Второе сообщение приходит (с автоматическим переподключением если нужно)
- ✅ Все последующие сообщения продолжают приходить
- ✅ Переподключение прозрачно для пользователя

---

## 💡 Дополнительные улучшения (будущее)

### 1. Connection Pool

Вместо одного `MCPService` для всех задач, можно создать pool соединений:
```swift
class MCPConnectionPool {
    private var connections: [MCPService] = []
    func getConnection() -> MCPService { ... }
    func releaseConnection(_ service: MCPService) { ... }
}
```

### 2. Keep-alive механизм

Периодически пинговать MCP сервер чтобы держать соединение живым:
```swift
Timer.scheduledTimer(withTimeInterval: 30) {
    try? await mcpService.callTool(name: "ping", arguments: nil)
}
```

### 3. Exponential backoff при повторных попытках

Если переподключение не удалось, подождать и попробовать снова:
```swift
var retryCount = 0
while retryCount < 3 {
    do {
        try await mcpService.connect()
        break
    } catch {
        retryCount += 1
        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
    }
}
```

### 4. Health check endpoint

Проверять здоровье MCP сервера перед каждым вызовом:
```swift
if !await isServerHealthy() {
    await reconnect()
}
```

---

## 📊 Статистика

**Файл изменён:** `AIAdventChatV2/Services/PeriodicTaskService.swift`

**Метод изменён:** `executeMCPTool()` (строки 141-208)

**Добавлено:**
- ✅ Try-catch обёртка вокруг callTool
- ✅ Проверка ошибки "not initialized"
- ✅ Вызов disconnect перед reconnect
- ✅ Retry логика после переподключения
- ✅ Подробное логирование

**Статус сборки:** ✅ **BUILD SUCCEEDED**

---

## ✅ Готово!

Теперь периодические задачи будут работать надёжно, автоматически переподключаясь при потере соединения.

**Протестируйте:**
```
Присылай погоду в Москве каждые 2 минуты
```

И наблюдайте логи в консоли Xcode - вы увидите автоматическое переподключение в действии! 🎉
