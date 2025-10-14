# Yandex Tracker MCP Integration Guide

## Обзор

Реализована полная интеграция Yandex Tracker через MCP (Model Context Protocol) с поддержкой агентов.

## Архитектура

```
YandexTrackerTestView (SwiftUI)
    ↓
YandexTrackerAgent (AI Agent)
    ↓
YandexTrackerService (Swift Wrapper)
    ↓
MCPService (MCP Client)
    ↓
Process (Node.js subprocess)
    ↓
Yandex Tracker MCP Server (TypeScript)
    ↓
Yandex Tracker API (REST)
```

## Компоненты

### 1. MCP Server (TypeScript/Node.js)

**Файл:** `/mcp-yandex-tracker/src/index.ts`

**Инструменты:**
- `configure` - Настройка учетных данных (orgId, token)
- `get_issues` - Получение списка задач
- `get_issue_stats` - Статистика по задачам
- `get_issue` - Детали конкретной задачи
- `get_my_issues` - Мои задачи

**Сборка:**
```bash
cd mcp-yandex-tracker
npm install
npm run build
```

### 2. YandexTrackerService (Swift)

**Файл:** `AIAdventChatV2/Services/YandexTrackerService.swift`

**Методы:**
- `configure(orgId:token:)` - Подключение к MCP серверу
- `getIssueStats(filter:)` - Получить статистику
- `getIssues(filter:limit:)` - Получить список задач
- `getIssue(key:)` - Получить задачу
- `getMyIssues()` - Получить мои задачи
- `getOpenTasksCount(filter:)` - Метод для агента
- `getTasksSummary(filter:)` - Краткая информация для агента

### 3. YandexTrackerAgent (Swift)

**Файл:** `AIAdventChatV2/Services/YandexTrackerAgent.swift`

**Возможности:**
- Анализ намерений пользователя
- Выполнение задач через YandexTrackerService
- Форматирование результатов для агента

**Методы:**
- `configure(orgId:token:)` - Настройка агента
- `executeTask(task:)` - Выполнить задачу
- `executeTaskWithAgent(task:)` - Выполнить с помощью Claude

### 4. YandexTrackerTestView (SwiftUI)

**Файл:** `AIAdventChatV2/Views/YandexTrackerTestView.swift`

**Интерфейс:**
- Форма конфигурации (orgId, token)
- Поле ввода задачи
- Отображение результата
- Примеры запросов

## Использование

### Шаг 1: Получение учетных данных Yandex Tracker

1. Зайдите в [Yandex Tracker](https://tracker.yandex.ru)
2. Получите Organization ID:
   - Настройки → О сервисе → ID организации
3. Создайте OAuth токен:
   - [OAuth приложения](https://oauth.yandex.ru/)
   - Создать приложение
   - Получить токен с правами на Tracker API

### Шаг 2: Запуск в приложении

1. Откройте приложение
2. Перейдите в YandexTrackerTestView
3. Введите Organization ID и OAuth Token
4. Нажмите "Настроить агента"

### Шаг 3: Выполнение задач

**Примеры запросов:**

```
1. Статистика:
   "Сколько открытых задач?"
   "Получи статистику по всем задачам"

2. Список задач:
   "Покажи все открытые задачи"
   "Какие задачи в работе?"

3. Информация о задаче:
   "Покажи информацию о задаче PROJECT-123"
```

### Шаг 4: Получение результата

Агент автоматически:
1. Анализирует ваш запрос
2. Определяет нужный инструмент
3. Вызывает MCP сервер
4. Форматирует и возвращает результат

## Примеры результатов

### Статистика задач

```
🎯 Результат анализа Yandex Tracker:

📊 Общая статистика:
• Всего задач: 42
• Открытых: 10
• В работе: 15
• Закрытых: 17

📈 Детальная статистика по статусам:
  • Open: 10
  • In Progress: 15
  • Closed: 17
```

## Интеграция с ContentView

Добавьте новую вкладку в `ContentView.swift`:

```swift
TabView(selection: $selectedTab) {
    // ... существующие вкладки

    NavigationStack {
        YandexTrackerTestView()
    }
    .tabItem {
        Label("Tracker", systemImage: "checklist")
    }
    .tag(3)
}
```

## API Reference

### YandexTrackerAgent

```swift
// Создание агента
let agent = YandexTrackerAgent(apiKey: "your-api-key")

// Конфигурация
try await agent.configure(
    orgId: "12345",
    token: "y0_AgAAAAAA..."
)

// Выполнение задачи
let result = try await agent.executeTask(
    task: "Сколько открытых задач?"
)

print(result)
// Output: 📊 Общая статистика: Всего задач: 42...
```

### YandexTrackerService

```swift
// Создание сервиса
let service = YandexTrackerService()

// Конфигурация
try await service.configure(
    orgId: "12345",
    token: "y0_AgAAAAAA..."
)

// Получение статистики
let stats = try await service.getIssueStats()
print("Открыто: \(stats.open)")

// С фильтром
let myStats = try await service.getIssueStats(filter: "assignee: me()")
```

## Фильтры Yandex Tracker

### Доступные фильтры:

```
1. По исполнителю:
   "assignee: me()"
   "assignee: username"

2. По статусу:
   "status: open"
   "status: closed"
   "status: inProgress"

3. По дате:
   "created: >= 2025-01-01"
   "updated: < 2025-02-01"

4. Комбинированные:
   "assignee: me() AND status: open"
```

## Расширение функциональности

### Добавление новых инструментов

1. **В MCP сервере** (`mcp-yandex-tracker/src/index.ts`):

```typescript
{
  name: "create_issue",
  description: "Create a new issue",
  inputSchema: {
    type: "object",
    properties: {
      queue: { type: "string" },
      summary: { type: "string" },
      description: { type: "string" }
    }
  }
}
```

2. **В YandexTrackerService**:

```swift
func createIssue(queue: String, summary: String, description: String) async throws -> YandexTrackerIssue {
    let args: [String: Value] = [
        "queue": .string(queue),
        "summary": .string(summary),
        "description": .string(description)
    ]

    let (content, isError) = try await mcpService.callTool(
        name: "create_issue",
        arguments: args
    )

    // Обработка результата
}
```

3. **В YandexTrackerAgent**:

```swift
case .createIssue:
    return try await handleCreateIssueTask(task)
```

## Troubleshooting

### Ошибка: "Not connected"

**Причина:** Агент не настроен или потеряно соединение

**Решение:**
1. Проверьте учетные данные
2. Убедитесь, что MCP сервер собран: `npm run build`
3. Проверьте путь к серверу в `YandexTrackerService.swift`

### Ошибка: "Failed to configure"

**Причина:** Неверные учетные данные или сервер не запустился

**Решение:**
1. Проверьте Organization ID и OAuth токен
2. Проверьте логи в Console.app (фильтр: "MCP Server")
3. Убедитесь, что Node.js установлен: `which node`

### Ошибка: "Transport error"

**Причина:** Проблема с запуском процесса

**Решение:**
1. Проверьте путь к `index.js`: `ls mcp-yandex-tracker/build/index.js`
2. Проверьте права доступа
3. Убедитесь, что `MCPService` работает с другими серверами

## Дальнейшее развитие

### Планируемые функции:

1. **Создание задач**
   - Добавить инструмент `create_issue`
   - Интегрировать с агентом

2. **Обновление задач**
   - Изменение статуса
   - Добавление комментариев
   - Назначение исполнителя

3. **Фильтрация и поиск**
   - Расширенные фильтры
   - Полнотекстовый поиск
   - Сохраненные фильтры

4. **Уведомления**
   - Webhook интеграция
   - Push уведомления
   - Периодическая проверка

5. **Визуализация**
   - Графики статистики
   - Kanban доска
   - Календарь задач

## Ресурсы

- [Yandex Tracker API Documentation](https://cloud.yandex.ru/docs/tracker/concepts/issues/get-issues)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)

## Заключение

Теперь у вас есть полноценная интеграция Yandex Tracker через MCP с поддержкой агентов!

Агент может:
- ✅ Анализировать запросы пользователя
- ✅ Вызывать нужные инструменты через MCP
- ✅ Получать данные из Yandex Tracker
- ✅ Форматировать результаты

**Готово к использованию! 🎉**
