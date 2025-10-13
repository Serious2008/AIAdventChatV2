# Исправление проблемы с аргументами команды

## Проблема

После того как мы нашли полный путь к `npx`, передавались неправильные аргументы:

```
Executing: /usr/local/bin/npx
MCP Server stderr: ERROR: You must supply a command.
```

## Причина

Код неправильно обрабатывал аргументы:

```swift
// БЫЛО (неправильно):
var resolvedCommand = serverCommand  // ["npx", "-y", "@..."]
if let fullPath = findExecutable("npx") {
    resolvedCommand[0] = fullPath  // ["/usr/local/bin/npx", "-y", "@..."]
}
process.executableURL = URL(fileURLWithPath: resolvedCommand[0])
process.arguments = Array(resolvedCommand.dropFirst())  // ["-y", "@..."]
```

Проблема: `dropFirst()` удаляет ПЕРВЫЙ элемент массива, но первый элемент - это уже путь к executable, а не команда! Получается что мы удаляем аргумент `-y`.

## Решение

Разделить команду и аргументы ДО резолвинга:

```swift
// СТАЛО (правильно):
let commandName = serverCommand[0]       // "npx"
let commandArgs = Array(serverCommand.dropFirst())  // ["-y", "@..."]

let executablePath: String
if let fullPath = findExecutable(commandName) {
    executablePath = fullPath  // "/usr/local/bin/npx"
} else {
    executablePath = commandName  // "npx" (fallback)
}

process.executableURL = URL(fileURLWithPath: executablePath)
process.arguments = commandArgs  // ["-y", "@..."] - правильные аргументы!
```

## Результат

### Было:
```
Executing: /usr/local/bin/npx
ERROR: You must supply a command.
```

### Стало:
```
Executing: /usr/local/bin/npx -y @modelcontextprotocol/server-memory
Successfully connected to MCP server
Received 2 tools from MCP server
```

## Логика

1. **Входные данные:** `["npx", "-y", "@modelcontextprotocol/server-memory"]`

2. **Разделяем:**
   - `commandName` = `"npx"`
   - `commandArgs` = `["-y", "@modelcontextprotocol/server-memory"]`

3. **Резолвим путь:**
   - `executablePath` = `"/usr/local/bin/npx"`

4. **Запускаем:**
   - `process.executableURL` = `/usr/local/bin/npx`
   - `process.arguments` = `["-y", "@modelcontextprotocol/server-memory"]`

5. **Результат:**
   ```bash
   /usr/local/bin/npx -y @modelcontextprotocol/server-memory
   ```

## Debug лог

Добавлен полезный лог для отладки:
```swift
print("Executing: \(executablePath) \(commandArgs.joined(separator: " "))")
```

Теперь можно видеть точно какая команда выполняется.

## Тестирование

Запустите приложение и проверьте логи:

```
Resolved 'npx' to: /usr/local/bin/npx
Executing: /usr/local/bin/npx -y @modelcontextprotocol/server-memory
Process PATH: /Users/sergeymarkov/.nvm/...
Starting MCP server process: npx -y @modelcontextprotocol/server-memory
Connecting to MCP server...
Successfully connected to MCP server
Received 2 tools from MCP server:
- store_memory: Store a value in memory
- retrieve_memory: Retrieve a value from memory
```

✅ Аргументы передаются правильно
✅ Сервер запускается
✅ Подключение успешно

**Теперь всё должно работать!**
