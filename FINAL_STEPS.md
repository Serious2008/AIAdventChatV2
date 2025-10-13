# Финальные шаги для запуска MCP

## ✅ Что уже готово:

1. ✅ MCP SDK настроен (`Package.swift`)
2. ✅ Создан сервис `MCPService.swift`
3. ✅ Создан тестовый UI `MCPTestView.swift`
4. ✅ Создан пример `MCPExample.swift`
5. ✅ Написана документация
6. ✅ Node.js проверен и работает
7. ✅ MCP сервер проверен и доступен
8. ✅ App Sandbox отключен

## 🎯 Что нужно сделать ВАМ:

### Шаг 1: Откройте проект в Xcode
```bash
open AIAdventChatV2.xcodeproj
```

### Шаг 2: Добавьте MCP SDK через Xcode

**ВАЖНО:** Это нужно сделать через интерфейс Xcode:

1. В Xcode: File → Add Package Dependencies...
2. Вставьте URL: `https://github.com/modelcontextprotocol/swift-sdk.git`
3. Выберите версию: `0.10.0` или выше (используйте "Up to Next Major")
4. Выберите продукт: `MCP`
5. Нажмите "Add Package"

**Скриншот процесса:**
```
┌─────────────────────────────────────────┐
│ Add Package Dependency                  │
├─────────────────────────────────────────┤
│ Enter Package URL:                      │
│ [https://github.com/modelcontext...   ]│
│                                         │
│ Dependency Rule:                        │
│ ⦿ Up to Next Major Version    [0.10.0] │
│                                         │
│ [Cancel]              [Add Package]     │
└─────────────────────────────────────────┘
```

### Шаг 3: Выберите способ тестирования

#### Вариант A: Использовать готовый UI (рекомендуется)

1. В Xcode найдите файл `MCPTestView.swift`
2. Измените `ContentView.swift` или создайте новое окно:

```swift
import SwiftUI

@main
struct AIAdventChatV2App: App {
    var body: some Scene {
        WindowGroup("MCP Test") {
            MCPTestView()
        }
    }
}
```

3. Запустите приложение (⌘R)
4. Используйте интерфейс для подключения

#### Вариант B: Интегрировать в существующий код

Добавьте в любой View:

```swift
import SwiftUI

struct YourView: View {
    @StateObject private var mcpService = MCPService()

    var body: some View {
        VStack {
            Button("Connect to MCP") {
                Task {
                    mcpService.initializeClient()
                    try? await mcpService.connect(
                        serverCommand: ["npx", "-y", "@modelcontextprotocol/server-memory"]
                    )
                }
            }

            if mcpService.isConnected {
                Text("Connected ✓").foregroundColor(.green)

                List(mcpService.availableTools) { tool in
                    VStack(alignment: .leading) {
                        Text(tool.name).bold()
                        Text(tool.description ?? "").font(.caption)
                    }
                }
            }
        }
    }
}
```

### Шаг 4: Запустите и проверьте

1. Запустите приложение через Xcode (⌘R)
2. Нажмите "Connect" (или используйте свой код)
3. Дождитесь подключения
4. Увидите список доступных инструментов!

## 🧪 Ожидаемый результат

После успешного подключения вы должны увидеть инструменты от Memory Server:

```
✓ Connected!

Available Tools (2):
  1. store_memory
     Description: Store a key-value pair in memory

  2. retrieve_memory
     Description: Retrieve a value from memory by key
```

## 🐛 Если что-то не работает

### Xcode не находит MCP SDK
➡️ Убедитесь, что:
- URL точный: `https://github.com/modelcontextprotocol/swift-sdk.git`
- Вы выбрали продукт `MCP` при добавлении
- У вас Xcode 16+ и включен Swift 6

### Ошибка компиляции "Cannot find 'Client' in scope"
➡️ Добавьте import в начало файла:
```swift
import MCP
```

### Ошибка во время выполнения "Connection failed"
➡️ Проверьте в терминале:
```bash
# Проверить Node.js
node --version

# Проверить доступность MCP сервера
npx @modelcontextprotocol/server-memory --version
```

### Приложение крашится при запуске
➡️ Убедитесь, что:
- App Sandbox отключен (проверьте `AIAdventChatV2.entitlements`)
- Сетевой доступ разрешен

## 📖 Документация

- **README_MCP.md** - начните отсюда!
- **MCP_QUICKSTART.md** - примеры кода
- **MCP_SETUP.md** - подробная настройка
- **MCP_SUMMARY.md** - полный обзор

## 🎓 Что дальше?

После успешного подключения попробуйте:

1. **Вызвать инструмент:**
```swift
let result = try await mcpService.callTool(
    name: "store_memory",
    arguments: ["key": "test", "value": "Hello MCP!"]
)
```

2. **Подключиться к другому серверу:**
```swift
// Filesystem server
try await mcpService.connect(
    serverCommand: ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
)

// Fetch server
try await mcpService.connect(
    serverCommand: ["npx", "-y", "@modelcontextprotocol/server-fetch"]
)
```

3. **Создать свой MCP сервер** (см. https://github.com/modelcontextprotocol/servers)

---

## 🚀 Готовы? Вперед!

```bash
# Откройте проект
open AIAdventChatV2.xcodeproj

# Затем следуйте Шагам 2-4 выше
```

**Удачи! Если возникнут вопросы - смотрите документацию в README_MCP.md**
