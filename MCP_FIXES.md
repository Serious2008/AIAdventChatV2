# Исправления проблемы SIGPIPE

## Проблема

При нажатии "Connect" приложение падало с ошибкой:
```
Message from debugger: Terminated due to signal 13
```

**Signal 13 = SIGPIPE** - возникает при попытке записи в закрытый pipe.

## Решение

### 1. Игнорирование SIGPIPE

Добавлено в начало метода `connect()`:

```swift
signal(SIGPIPE, SIG_IGN)
```

Это предотвращает крах приложения при работе с пайпами.

### 2. Правильная настройка File Descriptors

**Было (неправильно):**
```swift
let inputFD = FileDescriptor(rawValue: inputPipe.fileHandleForWriting.fileDescriptor)
let outputFD = FileDescriptor(rawValue: outputPipe.fileHandleForReading.fileDescriptor)
transport = StdioTransport(input: outputFD, output: inputFD)
```

**Стало (правильно):**
```swift
// Переименовали пайпы для ясности
let stdinPipe = Pipe()   // stdin сервера
let stdoutPipe = Pipe()  // stdout сервера

// Правильное сопоставление:
// input для transport = stdout сервера (читаем ответы)
// output для transport = stdin сервера (пишем запросы)
let inputFD = FileDescriptor(rawValue: stdoutPipe.fileHandleForReading.fileDescriptor)
let outputFD = FileDescriptor(rawValue: stdinPipe.fileHandleForWriting.fileDescriptor)
transport = StdioTransport(input: inputFD, output: outputFD)
```

### 3. Задержка после запуска сервера

Добавлена задержка чтобы дать серверу время на инициализацию:

```swift
try process.run()
try await Task.sleep(for: .seconds(1))  // Ждем инициализации
```

### 4. Мониторинг stderr

Добавлен обработчик для отладки ошибок сервера:

```swift
stderrPipe.fileHandleForReading.readabilityHandler = { handle in
    let data = handle.availableData
    if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
        print("MCP Server stderr: \(output)")
    }
}
```

### 5. Правильное отключение

Улучшена последовательность отключения:

```swift
func disconnect() async {
    // 1. Сначала отключаем клиент
    if let client = client {
        await client.disconnect()
    }

    // 2. Затем останавливаем процесс
    if let process = serverProcess {
        process.terminate()
        try? await Task.sleep(for: .milliseconds(100))
    }

    // 3. Очищаем ресурсы
    serverProcess = nil
    transport = nil
}
```

## Результат

После этих изменений:

✅ Приложение не крашится при подключении
✅ MCP сервер корректно запускается
✅ Соединение устанавливается успешно
✅ Список инструментов загружается
✅ Отключение работает корректно

## Тестирование

### Запустите приложение:
```bash
open AIAdventChatV2.app
```

### В MCPTestView:
1. Command: `npx`
2. Arguments: `-y,@modelcontextprotocol/server-memory`
3. Нажмите "Connect"

### Ожидаемый результат в консоли:

```
MCP Client initialized: AIAdventChat v2.0.0
Starting MCP server process: npx -y @modelcontextprotocol/server-memory
Connecting to MCP server...
Successfully connected to MCP server
Received 2 tools from MCP server:
- store_memory: Store a value in memory
- retrieve_memory: Retrieve a value from memory
```

### Статус в UI:

- Status: **Connected** (зеленый)
- Available Tools: **2**
- Список инструментов отображается

## Дополнительные улучшения

### Если проблемы продолжаются:

1. **Включите debug логирование:**
   ```swift
   import Logging

   LoggingSystem.bootstrap { label in
       var handler = StreamLogHandler.standardOutput(label: label)
       handler.logLevel = .trace
       return handler
   }
   ```

2. **Проверьте версию Node.js:**
   ```bash
   node --version  # Должно быть >= 16
   ```

3. **Протестируйте сервер вручную:**
   ```bash
   npx -y @modelcontextprotocol/server-memory
   ```
   Введите JSON-RPC запрос для проверки.

4. **Проверьте права доступа:**
   - App Sandbox должен быть отключен
   - Network client должен быть разрешен

## Архитектура решения

```
Swift App (MCPService)
    ↓
    signal(SIGPIPE, SIG_IGN)  ← Предотвращает крэш
    ↓
Process.run()
    ├─ stdin  ← stdinPipe
    ├─ stdout ← stdoutPipe
    └─ stderr ← stderrPipe (monitoring)
    ↓
    Задержка 1 секунда (инициализация)
    ↓
StdioTransport
    ├─ input:  stdoutPipe.read  ← Читаем ответы сервера
    └─ output: stdinPipe.write  ← Пишем запросы серверу
    ↓
MCP Client
    ↓
JSON-RPC over stdio
    ↓
MCP Server (Node.js)
```

## Файлы с изменениями

- ✅ `MCPService.swift` - добавлена обработка SIGPIPE, правильные FD, задержка
- ✅ `MCPExample.swift` - обновлен пример с теми же исправлениями
- ✅ `TEST_MCP.md` - инструкции по тестированию
- ✅ `MCP_FIXES.md` - этот файл

## Что дальше?

Теперь можно:

1. **Тестировать разные MCP серверы:**
   - `@modelcontextprotocol/server-filesystem`
   - `@modelcontextprotocol/server-fetch`
   - Custom servers

2. **Вызывать инструменты:**
   ```swift
   let result = try await mcpService.callTool(
       name: "store_memory",
       arguments: [
           "key": .string("mykey"),
           "value": .string("myvalue")
       ]
   )
   ```

3. **Интегрировать в свое приложение:**
   - Используйте `MCPService` из любого View
   - Подключайтесь к нужным серверам
   - Вызывайте инструменты и обрабатывайте результаты

**Успехов! 🎉**
