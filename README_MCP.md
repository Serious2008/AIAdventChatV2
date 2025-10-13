# MCP Integration для AIAdventChatV2

## Что это?

Model Context Protocol (MCP) - это открытый протокол для подключения AI-приложений к внешним инструментам и источникам данных.

## Быстрый старт (3 шага)

### 1️⃣ Установите MCP SDK в Xcode

```
1. Откройте AIAdventChatV2.xcodeproj
2. File → Add Package Dependencies
3. Вставьте: https://github.com/modelcontextprotocol/swift-sdk.git
4. Выберите версию 0.10.0+
5. Нажмите Add Package
```

### 2️⃣ Используйте готовый код

```swift
import SwiftUI

struct MyView: View {
    @StateObject private var mcpService = MCPService()

    var body: some View {
        VStack {
            Button("Подключиться к MCP") {
                Task {
                    mcpService.initializeClient()
                    try? await mcpService.connect(
                        serverCommand: ["npx", "-y", "@modelcontextprotocol/server-memory"]
                    )
                }
            }

            if mcpService.isConnected {
                Text("Подключено! ✓").foregroundColor(.green)

                ForEach(mcpService.availableTools) { tool in
                    Text("🔧 \(tool.name)")
                }
            }
        }
    }
}
```

### 3️⃣ Или используйте тестовый UI

```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            MCPTestView() // Готовый UI для тестирования
        }
    }
}
```

## Что создано?

### 📁 Основные файлы

| Файл | Описание |
|------|----------|
| `MCPService.swift` | Сервис для работы с MCP (подключение, инструменты) |
| `MCPTestView.swift` | UI для тестирования MCP подключения |
| `MCPExample.swift` | Standalone пример для командной строки |
| `Package.swift` | Конфигурация Swift Package Manager |

### 📚 Документация

| Файл | Для чего |
|------|----------|
| `README_MCP.md` | Этот файл - быстрый старт |
| `MCP_QUICKSTART.md` | Примеры кода и базовое использование |
| `MCP_SETUP.md` | Подробная инструкция по настройке |
| `MCP_SUMMARY.md` | Полный обзор и архитектура |

## Минимальный код

```swift
import Foundation
import MCP

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

// 1. Запуск MCP сервера как subprocess
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["npx", "-y", "@modelcontextprotocol/server-memory"]

let inputPipe = Pipe()
let outputPipe = Pipe()
process.standardInput = inputPipe
process.standardOutput = outputPipe
process.standardError = Pipe()

try process.run()

// 2. Создание транспорта с пайпами процесса
let inputFD = FileDescriptor(rawValue: inputPipe.fileHandleForWriting.fileDescriptor)
let outputFD = FileDescriptor(rawValue: outputPipe.fileHandleForReading.fileDescriptor)
let transport = StdioTransport(input: outputFD, output: inputFD)

// 3. Создание клиента и подключение
let client = Client(name: "MyApp", version: "1.0.0")
_ = try await client.connect(transport: transport)

// 4. Получение списка инструментов
let (tools, _) = try await client.listTools()

for tool in tools {
    print("Tool: \(tool.name)")
    print("Description: \(tool.description ?? "N/A")")
}

// 5. Отключение
await client.disconnect()
process.terminate()
```

## Примеры MCP серверов

### 🧠 Memory Server (рекомендуется для начала)
```swift
let command = ["npx", "-y", "@modelcontextprotocol/server-memory"]
```
**Что делает:** Key-value хранилище в памяти

### 📂 Filesystem Server
```swift
let command = ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/path/to/dir"]
```
**Что делает:** Чтение и запись файлов

### 🌐 Fetch Server
```swift
let command = ["npx", "-y", "@modelcontextprotocol/server-fetch"]
```
**Что делает:** HTTP запросы

## Требования

- ✅ Swift 6.0+ (Xcode 16+)
- ✅ macOS 15.5+
- ✅ Node.js (для запуска MCP серверов)
- ✅ App Sandbox отключен (уже настроено)

Проверьте Node.js:
```bash
node --version  # должно быть v16+
npm --version   # должно быть 8+
```

## Проблемы?

### "Package not found"
➡️ Добавьте MCP SDK через Xcode Package Dependencies

### "Connection failed"
➡️ Проверьте:
1. Node.js установлен: `node --version`
2. App Sandbox отключен в entitlements
3. Есть интернет для загрузки сервера

### "Client not initialized"
➡️ Вызовите `mcpService.initializeClient()` перед подключением

## Куда дальше?

1. **Для быстрого теста:** Запустите `MCPTestView`
2. **Для изучения кода:** Откройте `MCPExample.swift`
3. **Для интеграции:** Используйте `MCPService.swift`
4. **Для подробностей:** Читайте `MCP_SETUP.md`

## Полезные ссылки

- 📖 [Официальный Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- 📋 [MCP Specification](https://spec.modelcontextprotocol.io/)
- 🗂️ [Список MCP серверов](https://github.com/modelcontextprotocol/servers)
- 🌐 [MCP Hub](https://mcphub.tools/)

## Архитектура (упрощенно)

```
SwiftUI App
    ↓
MCPService
    ↓
MCP Swift SDK
    ↓
Process (stdio)
    ↓
MCP Server (Node.js)
```

---

**Начните с:** Откройте `MCPTestView.swift` и запустите его в Xcode после установки MCP SDK!
