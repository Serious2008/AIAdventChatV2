# MCP Quick Start Guide

## Быстрый старт: Минимальный код для работы с MCP

### 1. Установка MCP SDK через Xcode

**ВАЖНО:** Перед использованием кода необходимо добавить MCP SDK в проект через Xcode:

1. Откройте `AIAdventChatV2.xcodeproj` в Xcode
2. File → Add Package Dependencies...
3. Вставьте URL: `https://github.com/modelcontextprotocol/swift-sdk.git`
4. Выберите версию `0.10.0` или выше
5. Нажмите "Add Package"

### 2. Минимальный код подключения

```swift
import MCP

// Создание клиента
let client = Client(name: "MyApp", version: "1.0.0")

// Создание транспорта для подключения к серверу
let transport = StdioTransport(
    command: "npx",
    arguments: ["-y", "@modelcontextprotocol/server-memory"]
)

// Подключение
try await client.connect(transport: transport)

// Получение списка инструментов
let tools = try await client.listTools()

// Вывод информации о инструментах
for tool in tools {
    print("Tool: \(tool.name)")
    print("Description: \(tool.description ?? "N/A")")
}
```

### 3. Использование готового сервиса

В проекте создан готовый `MCPService` для упрощения работы:

```swift
import SwiftUI

struct ContentView: View {
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
                Text("Connected!")
                    .foregroundColor(.green)

                ForEach(mcpService.availableTools) { tool in
                    Text(tool.name)
                }
            }
        }
    }
}
```

### 4. Тестовый UI

Для быстрого тестирования используйте `MCPTestView`:

```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            MCPTestView() // Простой UI для тестирования MCP
        }
    }
}
```

### 5. Запуск примера из командной строки

Файл `MCPExample.swift` содержит standalone пример:

```bash
swift run MCPExample
```

Или запустите его через Xcode как отдельный target.

## Требования

- Swift 6.0+ (Xcode 16+)
- macOS 15.5+
- Node.js и npm (для запуска MCP серверов)
- App Sandbox должен быть отключен

## Популярные MCP серверы для тестирования

### 1. Memory Server
```swift
let command = ["npx", "-y", "@modelcontextprotocol/server-memory"]
```
Функции: сохранение и получение данных из памяти.

### 2. Filesystem Server
```swift
let command = ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/path/to/dir"]
```
Функции: чтение/запись файлов.

### 3. Fetch Server
```swift
let command = ["npx", "-y", "@modelcontextprotocol/server-fetch"]
```
Функции: HTTP запросы.

## Структура проекта

```
AIAdventChatV2/
├── Services/
│   └── MCPService.swift          # Основной сервис для работы с MCP
├── Views/
│   └── MCPTestView.swift         # UI для тестирования
├── MCPExample.swift              # Standalone пример
├── MCP_SETUP.md                  # Подробная документация
└── MCP_QUICKSTART.md             # Этот файл
```

## Следующие шаги

1. Откройте проект в Xcode
2. Добавьте MCP SDK через Package Dependencies
3. Запустите `MCPTestView` для визуального тестирования
4. Изучите `MCPService.swift` для интеграции в свое приложение

## Troubleshooting

**Ошибка: "Client not initialized"**
- Вызовите `mcpService.initializeClient()` перед подключением

**Ошибка: "Connection failed"**
- Убедитесь, что Node.js установлен: `node --version`
- Проверьте, что App Sandbox отключен в entitlements
- Убедитесь, что у вас есть интернет для загрузки MCP сервера

**Ошибка: "Package not found"**
- Добавьте MCP SDK через Xcode Package Dependencies
- Проверьте URL: `https://github.com/modelcontextprotocol/swift-sdk.git`

## Полезные ссылки

- [Официальный Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [Список MCP серверов](https://github.com/modelcontextprotocol/servers)
