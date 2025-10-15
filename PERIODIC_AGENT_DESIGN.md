# 🤖 Периодический агент для автоматических обновлений в чате

## 🎯 Задача

**Пользователь в чате:**
```
"Пиши мне информацию о погоде за последний час. Повторяй раз в час."
```

**Результат:**
- Каждый час в чате появляется новое сообщение от агента с погодой
- Работает автоматически в фоне
- Данные берутся из MCP сервера погоды

---

## 🏗️ Архитектура решения

### Компоненты:

```
┌─────────────────────────────────────────────────────────────┐
│ Пользователь в чате                                         │
│ "Пиши мне информацию о погоде. Повторяй раз в час"         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Claude с инструментами                                      │
│                                                             │
│ Claude понимает запрос и вызывает:                          │
│ create_periodic_task(                                       │
│     action: "get_weather_summary",                          │
│     interval: "1 hour",                                     │
│     parameters: { city: "Moscow" }                          │
│ )                                                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ PeriodicTaskService (Swift)                                 │
│                                                             │
│ 1. Создаёт задачу в БД                                     │
│ 2. Запускает Timer                                          │
│ 3. Возвращает подтверждение Claude                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Каждый час
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Task Executor                                               │
│                                                             │
│ 1. Вызывает MCP Weather Server                             │
│ 2. Получает данные о погоде                                 │
│ 3. Форматирует сообщение                                    │
│ 4. Добавляет в чат как сообщение от агента                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Chat (новое сообщение появляется автоматически)            │
│                                                             │
│ 🤖 Погодный агент • 14:00                                  │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                           │
│ 🌤️ Погода в Москве за последний час:                      │
│                                                             │
│ • Температура: +15°C                                        │
│ • Облачность: Переменная облачность                        │
│ • Ветер: 5 м/с, северо-западный                           │
│ • Влажность: 65%                                            │
│ • Давление: 745 мм рт. ст.                                 │
│                                                             │
│ Следующее обновление: 15:00                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Компоненты реализации

### 1. MCP Weather Server (Node.js)

Создаём отдельный MCP сервер для получения погоды:

```typescript
// mcp-weather-server/src/index.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import axios from "axios";

class WeatherMCPServer {
    private apiKey: string;

    constructor(apiKey: string) {
        this.apiKey = apiKey; // OpenWeatherMap API key
    }

    // Инструменты
    getTools() {
        return [
            {
                name: "get_current_weather",
                description: "Получить текущую погоду для указанного города",
                input_schema: {
                    type: "object",
                    properties: {
                        city: {
                            type: "string",
                            description: "Название города (например: Moscow, London)"
                        },
                        units: {
                            type: "string",
                            description: "Единицы измерения (metric или imperial)",
                            enum: ["metric", "imperial"]
                        }
                    },
                    required: ["city"]
                }
            },
            {
                name: "get_weather_summary",
                description: "Получить сводку погоды за последний час",
                input_schema: {
                    type: "object",
                    properties: {
                        city: {
                            type: "string",
                            description: "Название города"
                        }
                    },
                    required: ["city"]
                }
            }
        ];
    }

    async getCurrentWeather(city: string, units = "metric") {
        const url = `https://api.openweathermap.org/data/2.5/weather`;
        const response = await axios.get(url, {
            params: {
                q: city,
                appid: this.apiKey,
                units: units,
                lang: "ru"
            }
        });

        const data = response.data;
        return {
            city: data.name,
            temperature: data.main.temp,
            feels_like: data.main.feels_like,
            humidity: data.main.humidity,
            pressure: data.main.pressure,
            description: data.weather[0].description,
            wind_speed: data.wind.speed,
            wind_direction: this.getWindDirection(data.wind.deg),
            clouds: data.clouds.all,
            timestamp: new Date().toISOString()
        };
    }

    async getWeatherSummary(city: string) {
        const weather = await this.getCurrentWeather(city);

        return `🌤️ Погода в ${weather.city}:

• Температура: ${weather.temperature}°C (ощущается как ${weather.feels_like}°C)
• Состояние: ${weather.description}
• Ветер: ${weather.wind_speed} м/с, ${weather.wind_direction}
• Влажность: ${weather.humidity}%
• Давление: ${Math.round(weather.pressure * 0.75)} мм рт. ст.
• Облачность: ${weather.clouds}%

Обновлено: ${new Date(weather.timestamp).toLocaleTimeString('ru-RU')}`;
    }

    private getWindDirection(deg: number): string {
        const directions = [
            "северный", "северо-восточный", "восточный", "юго-восточный",
            "южный", "юго-западный", "западный", "северо-западный"
        ];
        return directions[Math.round(deg / 45) % 8];
    }
}

// Запуск сервера
const server = new WeatherMCPServer(process.env.OPENWEATHER_API_KEY || "");
// ... MCP server initialization
```

---

### 2. PeriodicTask Model (Swift)

```swift
// Models/PeriodicTask.swift
import Foundation

struct PeriodicTask: Codable, Identifiable {
    let id: UUID
    var action: String              // "get_weather_summary"
    var parameters: [String: String] // { "city": "Moscow" }
    var interval: TimeInterval       // 3600 (1 час в секундах)
    var isActive: Bool
    var createdAt: Date
    var lastExecutedAt: Date?
    var nextExecutionAt: Date
    var executionCount: Int

    init(action: String, parameters: [String: String], interval: TimeInterval) {
        self.id = UUID()
        self.action = action
        self.parameters = parameters
        self.interval = interval
        self.isActive = true
        self.createdAt = Date()
        self.lastExecutedAt = nil
        self.nextExecutionAt = Date().addingTimeInterval(interval)
        self.executionCount = 0
    }
}
```

---

### 3. PeriodicTaskService (Swift)

```swift
// Services/PeriodicTaskService.swift
import Foundation
import Combine

class PeriodicTaskService: ObservableObject {
    @Published var activeTasks: [PeriodicTask] = []

    private var timers: [UUID: Timer] = [:]
    private let weatherService: WeatherService
    private let chatViewModel: ChatViewModel

    init(weatherService: WeatherService, chatViewModel: ChatViewModel) {
        self.weatherService = weatherService
        self.chatViewModel = chatViewModel
        loadTasks()
    }

    // MARK: - Task Management

    func createTask(
        action: String,
        parameters: [String: String],
        intervalMinutes: Int
    ) -> PeriodicTask {
        let interval = TimeInterval(intervalMinutes * 60)
        let task = PeriodicTask(
            action: action,
            parameters: parameters,
            interval: interval
        )

        activeTasks.append(task)
        saveTasks()
        scheduleTask(task)

        return task
    }

    func stopTask(id: UUID) {
        if let index = activeTasks.firstIndex(where: { $0.id == id }) {
            activeTasks[index].isActive = false
            timers[id]?.invalidate()
            timers.removeValue(forKey: id)
            saveTasks()
        }
    }

    func resumeTask(id: UUID) {
        if let index = activeTasks.firstIndex(where: { $0.id == id }) {
            activeTasks[index].isActive = true
            scheduleTask(activeTasks[index])
            saveTasks()
        }
    }

    func deleteTask(id: UUID) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        activeTasks.removeAll { $0.id == id }
        saveTasks()
    }

    // MARK: - Task Execution

    private func scheduleTask(_ task: PeriodicTask) {
        // Отменяем существующий таймер если есть
        timers[task.id]?.invalidate()

        // Создаём новый таймер
        let timer = Timer.scheduledTimer(
            withTimeInterval: task.interval,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.executeTask(task)
            }
        }

        // Сохраняем таймер
        timers[task.id] = timer

        // Выполняем сразу при создании
        Task {
            await executeTask(task)
        }
    }

    private func executeTask(_ task: PeriodicTask) async {
        guard task.isActive else { return }

        print("🔄 Executing periodic task: \(task.action)")

        do {
            let result = try await performAction(
                action: task.action,
                parameters: task.parameters
            )

            // Обновляем статистику задачи
            if let index = activeTasks.firstIndex(where: { $0.id == task.id }) {
                activeTasks[index].lastExecutedAt = Date()
                activeTasks[index].nextExecutionAt = Date().addingTimeInterval(task.interval)
                activeTasks[index].executionCount += 1
                saveTasks()
            }

            // Добавляем результат в чат
            await addResultToChat(result: result, task: task)

        } catch {
            print("❌ Error executing periodic task: \(error)")
        }
    }

    private func performAction(
        action: String,
        parameters: [String: String]
    ) async throws -> String {
        switch action {
        case "get_weather_summary":
            guard let city = parameters["city"] else {
                throw NSError(domain: "PeriodicTask", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Missing city parameter"])
            }
            return try await weatherService.getWeatherSummary(city: city)

        case "get_yandex_tracker_stats":
            // Можно добавить и другие периодические задачи
            return try await getTrackerStats()

        default:
            throw NSError(domain: "PeriodicTask", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown action: \(action)"])
        }
    }

    private func addResultToChat(result: String, task: PeriodicTask) async {
        await MainActor.run {
            // Создаём специальное сообщение от агента
            let agentMessage = Message(
                content: result,
                isFromUser: false,
                isSystemMessage: false,
                metadata: [
                    "source": "periodic_agent",
                    "task_id": task.id.uuidString,
                    "action": task.action
                ]
            )

            chatViewModel.messages.append(agentMessage)
        }
    }

    // MARK: - Persistence

    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(activeTasks) {
            UserDefaults.standard.set(encoded, forKey: "PeriodicTasks")
        }
    }

    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "PeriodicTasks"),
           let tasks = try? JSONDecoder().decode([PeriodicTask].self, from: data) {
            self.activeTasks = tasks

            // Восстанавливаем таймеры для активных задач
            for task in tasks where task.isActive {
                scheduleTask(task)
            }
        }
    }

    // MARK: - Helper Methods

    func getActiveTasks() -> [PeriodicTask] {
        return activeTasks.filter { $0.isActive }
    }

    func getTaskStatus(id: UUID) -> String? {
        guard let task = activeTasks.first(where: { $0.id == id }) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if task.isActive {
            let nextExecution = formatter.string(from: task.nextExecutionAt)
            return "Активна • Следующий запуск: \(nextExecution)"
        } else {
            return "Приостановлена"
        }
    }
}
```

---

### 4. WeatherService (Swift)

```swift
// Services/WeatherService.swift
import Foundation

class WeatherService {
    private let mcpService: MCPService
    private var isConnected = false

    init() {
        self.mcpService = MCPService()
    }

    func configure() async throws {
        mcpService.initializeClient()

        // Путь к MCP weather server
        let serverPath = FileManager.default.currentDirectoryPath + "/mcp-weather-server/build/index.js"
        let command = ["node", serverPath]

        try await mcpService.connect(serverCommand: command)
        isConnected = true
    }

    func getWeatherSummary(city: String) async throws -> String {
        guard isConnected else {
            throw NSError(domain: "WeatherService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Weather service not connected"])
        }

        let result = try await mcpService.callTool(
            name: "get_weather_summary",
            arguments: ["city": .string(city)]
        )

        if result.isError {
            let errorText = extractTextFromContent(result.content)
            throw NSError(domain: "WeatherService", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: errorText])
        }

        return extractTextFromContent(result.content)
    }

    private func extractTextFromContent(_ content: [MCP.Tool.Content]) -> String {
        var result = ""
        for item in content {
            switch item {
            case .text(let text):
                result += text
            default:
                break
            }
        }
        return result
    }
}
```

---

### 5. PeriodicTaskTools (MCP Tools для Claude)

```swift
// Services/PeriodicTaskTools.swift
import Foundation

class PeriodicTaskToolsProvider {

    static func getTools() -> [ClaudeTool] {
        return [
            createPeriodicTaskTool(),
            listPeriodicTasksTool(),
            stopPeriodicTaskTool(),
            resumePeriodicTaskTool()
        ]
    }

    private static func createPeriodicTaskTool() -> ClaudeTool {
        return ClaudeTool(
            name: "create_periodic_task",
            description: """
            Создать периодическую задачу, которая будет выполняться автоматически с заданным интервалом.

            Используй этот инструмент когда пользователь просит:
            - "Присылай мне погоду каждый час"
            - "Показывай статистику задач каждое утро"
            - "Напоминай о чём-то регулярно"

            Доступные действия:
            - get_weather_summary: получить сводку погоды
            - get_yandex_tracker_stats: получить статистику из Tracker
            """,
            properties: [
                "action": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Действие для выполнения (get_weather_summary, get_yandex_tracker_stats)",
                    enum: ["get_weather_summary", "get_yandex_tracker_stats"]
                ),
                "parameters": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Параметры в формате JSON, например: {\"city\": \"Moscow\"}"
                ),
                "interval_minutes": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Интервал выполнения в минутах (например: 60 для часа, 1440 для суток)"
                )
            ],
            required: ["action", "interval_minutes"]
        )
    }

    private static func listPeriodicTasksTool() -> ClaudeTool {
        return ClaudeTool(
            name: "list_periodic_tasks",
            description: "Получить список всех активных периодических задач",
            properties: [:],
            required: nil
        )
    }

    private static func stopPeriodicTaskTool() -> ClaudeTool {
        return ClaudeTool(
            name: "stop_periodic_task",
            description: "Остановить периодическую задачу",
            properties: [
                "task_id": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "ID задачи для остановки"
                )
            ],
            required: ["task_id"]
        )
    }

    private static func resumePeriodicTaskTool() -> ClaudeTool {
        return ClaudeTool(
            name: "resume_periodic_task",
            description: "Возобновить остановленную периодическую задачу",
            properties: [
                "task_id": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "ID задачи для возобновления"
                )
            ],
            required: ["task_id"]
        )
    }

    // MARK: - Execution

    static func executeTool(
        name: String,
        input: [String: Any],
        periodicTaskService: PeriodicTaskService
    ) async throws -> String {
        switch name {
        case "create_periodic_task":
            return try await executeCreateTask(input: input, service: periodicTaskService)

        case "list_periodic_tasks":
            return executeListTasks(service: periodicTaskService)

        case "stop_periodic_task":
            return try executeStopTask(input: input, service: periodicTaskService)

        case "resume_periodic_task":
            return try executeResumeTask(input: input, service: periodicTaskService)

        default:
            throw NSError(domain: "PeriodicTaskTools", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown tool: \(name)"])
        }
    }

    private static func executeCreateTask(
        input: [String: Any],
        service: PeriodicTaskService
    ) async throws -> String {
        guard let action = input["action"] as? String,
              let intervalStr = input["interval_minutes"] as? String,
              let interval = Int(intervalStr) else {
            throw NSError(domain: "PeriodicTaskTools", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid parameters"])
        }

        var parameters: [String: String] = [:]
        if let paramsStr = input["parameters"] as? String,
           let paramsData = paramsStr.data(using: .utf8),
           let paramsDict = try? JSONDecoder().decode([String: String].self, from: paramsData) {
            parameters = paramsDict
        }

        let task = service.createTask(
            action: action,
            parameters: parameters,
            intervalMinutes: interval
        )

        return """
        ✅ Периодическая задача создана успешно!

        Действие: \(action)
        Интервал: каждые \(interval) минут
        ID задачи: \(task.id.uuidString)

        Первое выполнение начнётся прямо сейчас, следующее - через \(interval) минут.
        """
    }

    private static func executeListTasks(service: PeriodicTaskService) -> String {
        let tasks = service.getActiveTasks()

        if tasks.isEmpty {
            return "📋 Нет активных периодических задач."
        }

        var result = "📋 Активные периодические задачи:\n\n"

        for task in tasks {
            let intervalMin = Int(task.interval / 60)
            let status = service.getTaskStatus(id: task.id) ?? "Unknown"

            result += """
            • \(task.action)
              ID: \(task.id.uuidString.prefix(8))...
              Интервал: каждые \(intervalMin) минут
              Статус: \(status)
              Выполнено раз: \(task.executionCount)

            """
        }

        return result
    }

    private static func executeStopTask(
        input: [String: Any],
        service: PeriodicTaskService
    ) throws -> String {
        guard let taskIdStr = input["task_id"] as? String,
              let taskId = UUID(uuidString: taskIdStr) else {
            throw NSError(domain: "PeriodicTaskTools", code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid task_id"])
        }

        service.stopTask(id: taskId)
        return "⏸️ Задача \(taskIdStr.prefix(8))... остановлена."
    }

    private static func executeResumeTask(
        input: [String: Any],
        service: PeriodicTaskService
    ) throws -> String {
        guard let taskIdStr = input["task_id"] as? String,
              let taskId = UUID(uuidString: taskIdStr) else {
            throw NSError(domain: "PeriodicTaskTools", code: -4,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid task_id"])
        }

        service.resumeTask(id: taskId)
        return "▶️ Задача \(taskIdStr.prefix(8))... возобновлена."
    }
}
```

---

### 6. Интеграция с ChatViewModel

```swift
// В ChatViewModel.swift

class ChatViewModel: ObservableObject {
    // ... existing code

    private let periodicTaskService: PeriodicTaskService
    private let weatherService = WeatherService()

    init(settings: Settings) {
        self.settings = settings
        self.periodicTaskService = PeriodicTaskService(
            weatherService: weatherService,
            chatViewModel: self // передаём self для добавления сообщений
        )

        // Инициализируем weather service
        Task {
            try? await weatherService.configure()
        }
    }

    // В методе sendToClaudeDirectly добавляем инструменты
    func sendToClaudeDirectly(message: String) {
        // ... existing code ...

        // Добавляем periodic task tools
        let periodicTools = PeriodicTaskToolsProvider.getTools()
        tools.append(contentsOf: periodicTools)

        // ... rest of code
    }

    // В handleToolUse добавляем обработку periodic task tools
    private func handleToolUse(...) async {
        // ... existing code ...

        if toolName.starts(with: "create_periodic_task") ||
           toolName.starts(with: "list_periodic_tasks") ||
           toolName.starts(with: "stop_periodic_task") ||
           toolName.starts(with: "resume_periodic_task") {

            let result = try await PeriodicTaskToolsProvider.executeTool(
                name: toolName,
                input: toolInput,
                periodicTaskService: periodicTaskService
            )

            // Add result to toolResults
        }
    }
}
```

---

## 🎬 Пример использования

### Диалог 1: Создание задачи

```
👤 Пользователь:
Пиши мне информацию о погоде в Москве каждый час

🤖 Claude:
Хорошо! Я создам для вас периодическую задачу, которая будет
отправлять информацию о погоде в Москве каждый час.

[Claude вызывает create_periodic_task]

✅ Периодическая задача создана успешно!

Действие: get_weather_summary
Интервал: каждые 60 минут
ID задачи: a1b2c3d4...

Первое обновление отправлю прямо сейчас.
```

### Автоматическое сообщение (через час):

```
🤖 Погодный агент • 14:00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🌤️ Погода в Москве:

• Температура: +15°C (ощущается как +13°C)
• Состояние: переменная облачность
• Ветер: 5 м/с, северо-западный
• Влажность: 65%
• Давление: 745 мм рт. ст.
• Облачность: 40%

Обновлено: 14:00
Следующее обновление: 15:00
```

### Диалог 2: Управление задачами

```
👤 Пользователь:
Покажи активные задачи

🤖 Claude:
📋 Активные периодические задачи:

• get_weather_summary
  ID: a1b2c3d4...
  Интервал: каждые 60 минут
  Статус: Активна • Следующий запуск: 15:00
  Выполнено раз: 3
```

```
👤 Пользователь:
Останови задачу

🤖 Claude:
⏸️ Задача a1b2c3d4... остановлена.
Обновления погоды больше не будут приходить автоматически.
```

---

## 📊 Структура проекта

```
AIAdventChatV2/
├── Models/
│   └── PeriodicTask.swift                    # NEW
│
├── Services/
│   ├── PeriodicTaskService.swift            # NEW
│   ├── PeriodicTaskTools.swift              # NEW
│   ├── WeatherService.swift                 # NEW
│   ├── YandexTrackerService.swift
│   └── ClaudeService.swift
│
├── ViewModels/
│   └── ChatViewModel.swift                  # MODIFIED
│
└── Views/
    ├── ChatView.swift
    └── PeriodicTasksView.swift              # NEW (опционально)

mcp-weather-server/                           # NEW
├── package.json
├── src/
│   └── index.ts
└── build/
    └── index.js
```

---

## 🚀 План реализации

### Этап 1: MCP Weather Server (1 день)

1. Создать `mcp-weather-server/` проект
2. Получить API ключ от OpenWeatherMap (бесплатно)
3. Реализовать `get_weather_summary` инструмент
4. Собрать: `npm run build`

### Этап 2: PeriodicTaskService (1-2 дня)

1. Создать `PeriodicTask` модель
2. Реализовать `PeriodicTaskService` с Timer
3. Реализовать persistence (UserDefaults или SQLite)
4. Реализовать `WeatherService`

### Этап 3: MCP Tools интеграция (1 день)

1. Создать `PeriodicTaskTools`
2. Интегрировать с ChatViewModel
3. Добавить обработку tool_use для periodic tasks

### Этап 4: UI (опционально, 1 день)

1. Создать `PeriodicTasksView` для управления задачами
2. Показывать статус в интерфейсе
3. Кнопки старт/стоп

---

## 📝 Итого

### Что получится:

✅ Пользователь пишет: "Присылай погоду каждый час"
✅ Claude создаёт периодическую задачу
✅ Каждый час в чат автоматически приходит обновление погоды
✅ Можно остановить/возобновить через чат
✅ Можно посмотреть список активных задач

### Минимальный MVP (2-3 дня):

- Weather MCP Server
- PeriodicTaskService с Timer
- Интеграция с Claude
- Автоматические сообщения в чат

### Расширения (опционально):

- 🌍 Разные города
- 📊 Статистика из Yandex Tracker
- 📅 Разные интервалы (час, день, неделя)
- ⏰ Конкретное время (каждый день в 9:00)
- 🔔 Push уведомления вместо/вместе с сообщениями в чате

**Готовы начать реализацию?** 🚀
