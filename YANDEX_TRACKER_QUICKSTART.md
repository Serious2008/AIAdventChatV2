# Yandex Tracker MCP - Быстрый старт

## Что реализовано

✅ **MCP сервер** для Yandex Tracker (TypeScript/Node.js)
✅ **YandexTrackerService** - Swift обёртка над MCP
✅ **YandexTrackerAgent** - AI агент для работы с Tracker
✅ **YandexTrackerTestView** - UI для тестирования

## Быстрый тест

### 1. Проверка сборки MCP сервера

```bash
cd /Users/sergeymarkov/Documents/PetProject/AIAdventChatV2/mcp-yandex-tracker
ls build/index.js
```

Должен вывести:
```
build/index.js
```

✅ Сервер собран и готов к работе!

### 2. Добавление файлов в Xcode

Откройте проект в Xcode и добавьте новые файлы:

**Services:**
- `AIAdventChatV2/Services/YandexTrackerService.swift`
- `AIAdventChatV2/Services/YandexTrackerAgent.swift`

**Views:**
- `AIAdventChatV2/Views/YandexTrackerTestView.swift`

**Как добавить:**
1. В Xcode: File → Add Files to "AIAdventChatV2"
2. Выберите файлы
3. Убедитесь, что они добавлены в Target

### 3. Добавление вкладки (опционально)

Отредактируйте `ContentView.swift`:

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

### 4. Запуск тестирования

#### Вариант A: Через UI (YandexTrackerTestView)

1. Запустите приложение
2. Откройте вкладку "Tracker" (или через Preview)
3. Введите учетные данные:
   - **Organization ID**: Ваш ID организации в Yandex Tracker
   - **OAuth Token**: Ваш токен доступа
4. Нажмите "Настроить агента"
5. Введите запрос: "Сколько открытых задач?"
6. Нажмите "Выполнить задачу"

#### Вариант B: Программный тест

Создайте тестовую функцию:

```swift
func testYandexTrackerAgent() async {
    let agent = YandexTrackerAgent(apiKey: "your-claude-api-key")

    do {
        // Настройка
        try await agent.configure(
            orgId: "12345",
            token: "y0_AgAAAAAA..."
        )

        // Выполнение задачи
        let result = try await agent.executeTask(
            task: "Сколько открытых задач?"
        )

        print("✅ Результат от агента:")
        print(result)

    } catch {
        print("❌ Ошибка: \(error)")
    }
}
```

### 5. Ожидаемый результат

Агент должен вернуть что-то вроде:

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

## Архитектура вызова

```
Пользователь
    ↓
    "Сколько открытых задач?"
    ↓
YandexTrackerAgent.executeTask()
    ↓ (анализирует intent)
    ↓
YandexTrackerService.getIssueStats()
    ↓
MCPService.callTool("get_issue_stats")
    ↓ (JSON-RPC через pipes)
    ↓
Node.js Process (mcp-yandex-tracker/build/index.js)
    ↓
Yandex Tracker API (HTTP)
    ↓
Результат ← ← ← ← ← ← ← ←
```

## Примеры запросов для агента

### Статистика

```
"Сколько открытых задач?"
"Получи статистику по всем задачам"
"Какая статистика по задачам?"
```

### Фильтрация

```
"Сколько моих задач?"  → filter: "assignee: me()"
"Покажи открытые задачи" → filter: "status: open"
```

### Конкретная задача

```
"Покажи информацию о задаче PROJECT-123"
"Детали задачи MYPROJ-456"
```

## Получение учетных данных

### Organization ID

1. Зайдите в [Yandex Tracker](https://tracker.yandex.ru)
2. Настройки → О сервисе
3. Скопируйте "ID организации"

### OAuth Token

1. Перейдите на [OAuth приложения](https://oauth.yandex.ru/)
2. Создайте приложение
3. Получите токен с правами:
   - `tracker:read`
   - `tracker:write` (если нужно создавать задачи)

## Troubleshooting

### Проблема: "Not connected"

**Решение:**
```bash
# Проверьте, что сервер собран
ls mcp-yandex-tracker/build/index.js

# Если нет, соберите:
cd mcp-yandex-tracker
npm run build
```

### Проблема: "Failed to configure"

**Возможные причины:**
1. Неверный Organization ID или Token
2. Node.js не найден (проверьте `which node`)
3. Путь к серверу неверный

**Решение:**
Проверьте путь в `YandexTrackerService.swift:54`:
```swift
let serverPath = "\(projectPath)/mcp-yandex-tracker/build/index.js"
```

### Проблема: Компиляция Swift не проходит

**Решение:**
1. Убедитесь, что файлы добавлены в Target
2. Проверьте импорты: `import Foundation`, `import SwiftUI`
3. Убедитесь, что `MCPService.swift` уже в проекте

## Логи для отладки

Проверьте Console.app (macOS):

```
Фильтр: "MCP Server" или "Yandex Tracker"
```

Или добавьте отладочные принты:

```swift
// В YandexTrackerService.swift
print("🔍 Calling MCP tool: \(name)")
print("📥 Arguments: \(arguments ?? [:])")
print("📤 Result: \(content)")
```

## Следующие шаги

1. **Тестирование** - Запустите и проверьте работу агента
2. **Интеграция с чатом** - Добавьте вызов из ChatViewModel
3. **Расширение** - Добавьте новые инструменты (создание задач, обновление)

## Полная документация

См. `YANDEX_TRACKER_MCP_GUIDE.md` для детальной информации.

---

**Готово! Агент настроен и готов к работе с Yandex Tracker через MCP! 🚀**
