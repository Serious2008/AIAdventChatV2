# Тестирование MCP подключения

## Проблема: SIGPIPE (Signal 13)

### Что было сделано:

1. **Добавлена обработка SIGPIPE**
   ```swift
   signal(SIGPIPE, SIG_IGN)
   ```
   Это предотвращает крах приложения при записи в закрытый pipe.

2. **Правильная настройка дескрипторов**
   - `input` для transport = stdout сервера (читаем из сервера)
   - `output` для transport = stdin сервера (пишем в сервер)

3. **Добавлена задержка после запуска сервера**
   ```swift
   try await Task.sleep(for: .seconds(1))
   ```
   Даем серверу время на инициализацию перед подключением.

4. **Добавлен мониторинг stderr**
   Теперь можно видеть ошибки сервера в консоли.

5. **Улучшено отключение**
   - Правильный порядок: сначала клиент, потом процесс
   - Задержка перед завершением процесса
   - Очистка всех ресурсов

## Как тестировать:

### 1. Запустите приложение
```bash
open AIAdventChatV2.app
```

### 2. В MCPTestView:
- Command: `npx`
- Arguments: `-y,@modelcontextprotocol/server-memory`
- Нажмите "Connect"

### 3. Проверьте логи в Xcode Console

Вы должны увидеть:
```
MCP Client initialized: AIAdventChat v2.0.0
Starting MCP server process: npx -y @modelcontextprotocol/server-memory
Connecting to MCP server...
Successfully connected to MCP server
Received 2 tools from MCP server:
- store_memory: ...
- retrieve_memory: ...
```

## Если все еще есть проблемы:

### Проверка 1: Тест в терминале
```bash
npx -y @modelcontextprotocol/server-memory
```
Сервер должен запуститься и ждать ввода.

### Проверка 2: Проверьте процесс
```bash
ps aux | grep @modelcontextprotocol
```

### Проверка 3: Проверьте логи stderr
В консоли Xcode должны быть видны сообщения от сервера с префиксом "MCP Server stderr:".

## Альтернативное решение:

Если проблема с SIGPIPE продолжается, можно попробовать использовать HTTPClientTransport вместо StdioTransport:

```swift
// Запустить MCP сервер через HTTP
let transport = HTTPClientTransport(
    endpoint: URL(string: "http://localhost:3000")!,
    streaming: true
)
```

Но для этого нужен MCP сервер с HTTP support.

## Debug советы:

1. **Включите подробное логирование:**
   ```swift
   import Logging

   LoggingSystem.bootstrap { label in
       var handler = StreamLogHandler.standardOutput(label: label)
       handler.logLevel = .trace
       return handler
   }
   ```

2. **Добавьте breakpoint в MCPService.swift:64** (после process.run())
   Проверьте что процесс запустился успешно.

3. **Проверьте entitlements:**
   Убедитесь что `com.apple.security.app-sandbox` = `false`

## Ожидаемое поведение:

После успешного подключения вы увидите список инструментов:

- **store_memory** - Сохранить данные в память
- **retrieve_memory** - Получить данные из памяти

Статус должен измениться с "Disconnected" на "Connected" (зеленый).
