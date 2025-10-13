# Проблема с устаревшей версией npx

## Симптом

Аргументы передаются правильно, но npx выдает ошибку:

```
🚀 Executing: /usr/local/bin/npx
   Arguments: ["-y", "@modelcontextprotocol/server-memory"]
   Full command: /usr/local/bin/npx -y @modelcontextprotocol/server-memory

MCP Server stderr: ERROR: You must supply a command.
```

## Причина

`/usr/local/bin/npx` оказался устаревшей версией от 2018 года:

```bash
$ ls -la /usr/local/bin/npx
lrwxr-xr-x  1 sergeymarkov  admin  46 Nov 11  2018 /usr/local/bin/npx -> /usr/local/lib/node_modules/npm/bin/npx-cli.js

$ which -a npx
/Users/sergeymarkov/.nvm/versions/node/v22.18.0/bin/npx  ← Современная версия
/usr/local/bin/npx                                       ← Старая версия (2018)
/opt/homebrew/bin/npx
```

**Проблема:** Старая версия `npx` (2018 года) не поддерживает современный синтаксис или имеет баги с обработкой аргументов.

## Решение

Изменен порядок поиска в `findExecutable()` - теперь приоритет у современных версий:

```swift
let searchPaths = [
    // Пути от nvm (приоритет - современные версии)
    "\(NSHomeDirectory())/.nvm/versions/node/v22.18.0/bin",  // ← ПЕРВЫЙ!
    "\(NSHomeDirectory())/.nvm/current/bin",
    // Volta
    "\(NSHomeDirectory())/.volta/bin",
    // npm global
    "\(NSHomeDirectory())/.npm-global/bin",
    // Homebrew node (современная версия)
    "/opt/homebrew/opt/node/bin",
    "/opt/homebrew/bin",
    // Стандартные пути (могут быть устаревшими)
    "/usr/local/bin",  // ← Старая версия проверяется последней
    "/usr/bin",
    "/bin",
]
```

## Результат

### До исправления:
```
✅ Resolved 'npx' to: /usr/local/bin/npx
ERROR: You must supply a command.
```

### После исправления:
```
✅ Resolved 'npx' to: /Users/sergeymarkov/.nvm/versions/node/v22.18.0/bin/npx
Successfully connected to MCP server
Received 2 tools from MCP server
```

## Как проверить у себя

### 1. Найти все версии npx:
```bash
which -a npx
```

### 2. Проверить дату создания:
```bash
ls -la /usr/local/bin/npx
```

### 3. Проверить версии:
```bash
# Современная версия (nvm)
~/.nvm/versions/node/v22.18.0/bin/npx --version
# 10.9.3 (современная)

# Старая версия
/usr/local/bin/npx --version
# Возможно старая или не работает
```

## Альтернативное решение

Если хотите использовать конкретную версию, укажите полный путь в UI:

### Вариант 1: nvm версия
```
Command: /Users/YOUR_USERNAME/.nvm/versions/node/v22.18.0/bin/npx
Arguments: -y,@modelcontextprotocol/server-memory
```

### Вариант 2: Удалить старую версию
```bash
rm /usr/local/bin/npx
```

Теперь `which npx` будет находить только современную версию.

### Вариант 3: Использовать node напрямую
```
Command: /Users/YOUR_USERNAME/.nvm/versions/node/v22.18.0/bin/node
Arguments: /Users/YOUR_USERNAME/.nvm/versions/node/v22.18.0/bin/npx,-y,@modelcontextprotocol/server-memory
```

## Урок

**Всегда отдавайте приоритет версиям из менеджеров пакетов (nvm, volta) перед системными путями (/usr/local/bin).**

Менеджеры пакетов обновляются чаще и содержат актуальные версии инструментов.

## Диагностика

Если видите странные ошибки от npx/node:

1. Проверьте какая версия используется:
   ```bash
   which npx
   ls -la $(which npx)
   ```

2. Проверьте дату модификации:
   ```bash
   stat $(which npx)
   ```

3. Попробуйте явно указать современную версию:
   ```bash
   ~/.nvm/versions/node/v22.18.0/bin/npx -y @modelcontextprotocol/server-memory
   ```

**Теперь должно работать с современной версией npx!** 🎉
