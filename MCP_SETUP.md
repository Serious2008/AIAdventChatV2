# MCP (Model Context Protocol) Setup Guide

## Что такое MCP?

Model Context Protocol (MCP) - это открытый протокол для стандартизации интеграции между AI-приложениями и внешними источниками данных и инструментами.

## Установка

### 1. Добавление MCP SDK через Xcode

1. Откройте проект `AIAdventChatV2.xcodeproj` в Xcode
2. Выберите проект в навигаторе проектов
3. Выберите таргет `AIAdventChatV2`
4. Перейдите на вкладку `Package Dependencies`
5. Нажмите кнопку `+` (Add Package)
6. Вставьте URL: `https://github.com/modelcontextprotocol/swift-sdk.git`
7. Выберите версию: `0.10.0` или выше
8. Нажмите `Add Package`
9. Выберите продукт `MCP` и нажмите `Add Package`

### 2. Требования

- Swift 6.0+ (Xcode 16+)
- macOS 15.5+
- App Sandbox должен быть отключен (уже настроено в `AIAdventChatV2.entitlements`)

## Минимальный код для подключения

### Инициализация клиента

```swift
import MCP

let mcpService = MCPService()
mcpService.initializeClient()
```

### Подключение к MCP серверу

```swift
// Пример подключения к memory server
let serverCommand = ["npx", "-y", "@modelcontextprotocol/server-memory"]

Task {
    do {
        try await mcpService.connect(serverCommand: serverCommand)
        print("Connected!")
    } catch {
        print("Connection failed: \(error)")
    }
}
```

### Получение списка доступных инструментов

```swift
Task {
    do {
        try await mcpService.fetchAvailableTools()

        // Доступные инструменты теперь в mcpService.availableTools
        for tool in mcpService.availableTools {
            print("Tool: \(tool.name)")
            print("Description: \(tool.description ?? "N/A")")
        }
    } catch {
        print("Failed to fetch tools: \(error)")
    }
}
```

### Вызов инструмента

```swift
Task {
    do {
        let result = try await mcpService.callTool(
            name: "tool_name",
            arguments: ["key": "value"]
        )
        print("Result: \(result.content)")
    } catch {
        print("Tool call failed: \(error)")
    }
}
```

## Тестовый UI

В проекте создан `MCPTestView` для тестирования MCP подключения:

1. Запустите приложение
2. Откройте `MCPTestView`
3. Введите команду для запуска MCP сервера (по умолчанию: `npx`)
4. Введите аргументы (по умолчанию: `-y,@modelcontextprotocol/server-memory`)
5. Нажмите "Connect"
6. После успешного подключения вы увидите список доступных инструментов

## Примеры MCP серверов

### Memory Server (официальный)
```
Команда: npx
Аргументы: -y,@modelcontextprotocol/server-memory
```
Предоставляет инструменты для работы с памятью (сохранение/получение данных).

### Filesystem Server (официальный)
```
Команда: npx
Аргументы: -y,@modelcontextprotocol/server-filesystem,/path/to/directory
```
Предоставляет инструменты для работы с файловой системой.

### Weather Server (пример)
```
Команда: npx
Аргументы: -y,@modelcontextprotocol/server-weather
```
Предоставляет инструменты для получения погодных данных.

## Структура кода

### MCPService.swift
Основной сервис для работы с MCP:
- `initializeClient()` - инициализация клиента
- `connect(serverCommand:)` - подключение к серверу
- `fetchAvailableTools()` - получение списка инструментов
- `callTool(name:arguments:)` - вызов инструмента
- `disconnect()` - отключение от сервера

### MCPTestView.swift
UI для тестирования MCP подключения и просмотра доступных инструментов.

## Типичные ошибки

### "Client not initialized"
Решение: Вызовите `mcpService.initializeClient()` перед подключением.

### "Transport creation failed"
Решение: Проверьте, что команда и аргументы сервера корректны.

### "Connection failed"
Решение:
- Убедитесь, что MCP сервер установлен (`npx` должен работать)
- Проверьте, что App Sandbox отключен в entitlements
- Проверьте доступ к сети в настройках безопасности

## Дополнительные ресурсы

- [Официальный Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [List of MCP Servers](https://github.com/modelcontextprotocol/servers)
