# Исправление проблемы с PATH для Node.js команд

## Проблемы

### Проблема 1: npx не найден
```
MCP Server stderr: env: npx: No such file or directory
Failed to connect: [-32001] Transport error: Broken pipe
```

### Проблема 2: node не найден (после исправления проблемы 1)
```
Resolved 'npx' to: /usr/local/bin/npx
MCP Server stderr: env: node: No such file or directory
Failed to connect: [-32001] Transport error: Broken pipe
```

## Причина

Когда macOS приложение запускается через GUI (не из терминала), оно не имеет доступа к PATH из вашего shell (bash/zsh). Это означает:
1. Команды вроде `npx`, установленные через nvm, недоступны
2. Даже если `npx` найден, он не может найти `node` для выполнения

## Решение

### Часть 1: Поиск исполняемых файлов

Добавлена функция `findExecutable()` которая ищет исполняемые файлы в:

1. **PATH из окружения приложения** (если доступен)
2. **Стандартные пути:**
   - `/usr/local/bin`
   - `/usr/bin`
   - `/bin`
   - `/opt/homebrew/bin`

3. **Специфичные пути Node.js:**
   - `~/.nvm/versions/node/v22.18.0/bin` (текущая версия)
   - `~/.nvm/current/bin` (симлинк на текущую)
   - `~/.npm-global/bin` (npm global)
   - `~/.volta/bin` (Volta package manager)
   - `/opt/homebrew/opt/node/bin` (Homebrew)

4. **Fallback через `which`:**
   Если ничего не найдено, запускаем `/usr/bin/which npx`

### Часть 2: Настройка окружения процесса

**КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ:** Добавление PATH в окружение запускаемого процесса:

```swift
var environment = ProcessInfo.processInfo.environment

let additionalPaths = [
    "\(NSHomeDirectory())/.nvm/versions/node/v22.18.0/bin",
    "\(NSHomeDirectory())/.nvm/current/bin",
    "\(NSHomeDirectory())/.npm-global/bin",
    "\(NSHomeDirectory())/.volta/bin",
    "/usr/local/bin",
    "/usr/bin",
    "/bin",
    "/opt/homebrew/bin",
    "/opt/homebrew/opt/node/bin",
].joined(separator: ":")

let existingPath = environment["PATH"] ?? ""
environment["PATH"] = "\(additionalPaths):\(existingPath)"
process.environment = environment
```

Теперь когда `npx` запускается, он может найти `node` в PATH!

## Как это работает

### До исправления (не работало):
```swift
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["npx", "-y", "@modelcontextprotocol/server-memory"]
```
❌ Проблемы:
- `env` не может найти `npx` (PATH не содержит nvm пути)
- Даже если найдет, `npx` не может найти `node`

### После исправления (работает):
```swift
// 1. Находим полный путь к npx
let fullPath = findExecutable("npx")
// Результат: /Users/sergeymarkov/.nvm/versions/node/v22.18.0/bin/npx

// 2. Настраиваем PATH для процесса
var environment = ProcessInfo.processInfo.environment
environment["PATH"] = "~/.nvm/.../bin:/usr/local/bin:..."
process.environment = environment

// 3. Запускаем процесс с правильным окружением
process.executableURL = URL(fileURLWithPath: fullPath)
process.arguments = ["-y", "@modelcontextprotocol/server-memory"]
```
✅ `npx` найден и запущен с правильным PATH
✅ `npx` может найти `node` в PATH процесса

## Логи

Теперь в консоли вы увидите:
```
Resolved 'npx' to: /usr/local/bin/npx
Process PATH: /Users/sergeymarkov/.nvm/versions/node/v22.18.0/bin:...
Starting MCP server process: npx -y @modelcontextprotocol/server-memory
Connecting to MCP server...
Successfully connected to MCP server
Received 2 tools from MCP server:
- store_memory: Store a value in memory
- retrieve_memory: Retrieve a value from memory
```

## Альтернативные решения

### Вариант 1: Использовать полный путь в UI

Вместо:
```
Command: npx
Arguments: -y,@modelcontextprotocol/server-memory
```

Используйте:
```
Command: /Users/YOUR_USERNAME/.nvm/versions/node/v22.18.0/bin/npx
Arguments: -y,@modelcontextprotocol/server-memory
```

### Вариант 2: Создать симлинк

```bash
sudo ln -s ~/.nvm/versions/node/v22.18.0/bin/npx /usr/local/bin/npx
```

Теперь `npx` доступен по стандартному пути.

### Вариант 3: Использовать node напрямую

```
Command: /Users/YOUR_USERNAME/.nvm/versions/node/v22.18.0/bin/node
Arguments: /Users/YOUR_USERNAME/.nvm/versions/node/v22.18.0/bin/npx,-y,@modelcontextprotocol/server-memory
```

## Для разработчиков

Если вы используете другой менеджер Node.js, добавьте путь в `findExecutable()`:

```swift
let searchPaths = [
    // ... существующие пути ...

    // Ваш кастомный путь
    "\(NSHomeDirectory())/.your-node-manager/bin",
]
```

## Проверка

Узнайте где находится ваш `npx`:

```bash
which npx
# Вывод: /Users/sergeymarkov/.nvm/versions/node/v22.18.0/bin/npx
```

Проверьте что он исполняемый:

```bash
ls -l $(which npx)
# Вывод: -rwxr-xr-x ... /Users/sergeymarkov/.nvm/versions/node/v22.18.0/bin/npx
```

## Тестирование

1. **Запустите приложение через Xcode** (⌘R)
2. **В MCPTestView введите:**
   - Command: `npx`
   - Arguments: `-y,@modelcontextprotocol/server-memory`
3. **Нажмите Connect**
4. **Проверьте консоль:**
   - Должна быть строка "Resolved 'npx' to: ..."
   - Подключение должно быть успешным

## Результат

✅ Автоматическое определение пути к `npx`
✅ Поддержка nvm, Volta, Homebrew, npm global
✅ Работает из GUI приложения
✅ Fallback через `which` если ничего не найдено

**Теперь приложение должно находить npx автоматически!**
