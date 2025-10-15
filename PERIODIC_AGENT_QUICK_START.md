# ⚡ Quick Start: Периодический погодный агент

## 🎯 Цель

Пользователь пишет: **"Пиши мне погоду каждый час"**
→ Каждый час в чате автоматически появляется обновление погоды

---

## 📋 Что нужно сделать (3 простых шага)

### Шаг 1: MCP Weather Server (30 минут)

```bash
# 1. Создаём проект
mkdir mcp-weather-server
cd mcp-weather-server
npm init -y

# 2. Устанавливаем зависимости
npm install @modelcontextprotocol/sdk axios

# 3. Получаем бесплатный API ключ
# https://openweathermap.org/api
# Зарегистрируйтесь и получите ключ

# 4. Создаём .env
echo "OPENWEATHER_API_KEY=ваш_ключ_здесь" > .env

# 5. Собираем
npm run build
```

**Файл:** `mcp-weather-server/src/index.ts`
```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import axios from "axios";

const API_KEY = process.env.OPENWEATHER_API_KEY;

async function getWeatherSummary(city: string) {
    const url = `https://api.openweathermap.org/data/2.5/weather`;
    const response = await axios.get(url, {
        params: {
            q: city,
            appid: API_KEY,
            units: "metric",
            lang: "ru"
        }
    });

    const data = response.data;
    return `🌤️ Погода в ${data.name}:
• Температура: ${data.main.temp}°C
• Состояние: ${data.weather[0].description}
• Ветер: ${data.wind.speed} м/с
• Влажность: ${data.main.humidity}%`;
}

// MCP Server setup...
```

---

### Шаг 2: PeriodicTaskService (1 час)

**Файл:** `Services/PeriodicTaskService.swift`

```swift
import Foundation

class PeriodicTaskService: ObservableObject {
    weak var chatViewModel: ChatViewModel?
    private var timers: [UUID: Timer] = [:]

    func createTask(city: String, intervalMinutes: Int) {
        let taskId = UUID()
        let interval = TimeInterval(intervalMinutes * 60)

        let timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.sendWeatherUpdate(city: city)
            }
        }

        timers[taskId] = timer

        // Выполняем сразу
        Task {
            await sendWeatherUpdate(city: city)
        }
    }

    private func sendWeatherUpdate(city: String) async {
        // 1. Получаем погоду из MCP
        guard let weather = try? await getWeatherFromMCP(city: city) else {
            return
        }

        // 2. Добавляем в чат
        await MainActor.run {
            let message = Message(
                content: weather,
                isFromUser: false
            )
            chatViewModel?.messages.append(message)
        }
    }

    private func getWeatherFromMCP(city: String) async throws -> String {
        // Вызов MCP weather server
        let mcpService = MCPService()
        mcpService.initializeClient()

        let serverPath = FileManager.default.currentDirectoryPath +
                        "/mcp-weather-server/build/index.js"
        try await mcpService.connect(serverCommand: ["node", serverPath])

        let result = try await mcpService.callTool(
            name: "get_weather_summary",
            arguments: ["city": .string(city)]
        )

        return extractText(from: result.content)
    }
}
```

---

### Шаг 3: Интеграция с Claude (30 минут)

**Файл:** `Services/PeriodicTaskTools.swift`

```swift
class PeriodicTaskToolsProvider {
    static func getTools() -> [ClaudeTool] {
        return [
            ClaudeTool(
                name: "start_weather_updates",
                description: "Начать автоматические обновления погоды с заданным интервалом",
                properties: [
                    "city": ClaudeTool.InputSchema.Property(
                        type: "string",
                        description: "Город для погоды"
                    ),
                    "interval_minutes": ClaudeTool.InputSchema.Property(
                        type: "string",
                        description: "Интервал в минутах (60 = час)"
                    )
                ],
                required: ["city", "interval_minutes"]
            )
        ]
    }

    static func executeTool(
        name: String,
        input: [String: Any],
        periodicTaskService: PeriodicTaskService
    ) -> String {
        guard let city = input["city"] as? String,
              let intervalStr = input["interval_minutes"] as? String,
              let interval = Int(intervalStr) else {
            return "❌ Неверные параметры"
        }

        periodicTaskService.createTask(
            city: city,
            intervalMinutes: interval
        )

        return "✅ Буду присылать погоду в \(city) каждые \(interval) минут!"
    }
}
```

**В ChatViewModel.swift добавляем:**

```swift
class ChatViewModel: ObservableObject {
    private let periodicTaskService = PeriodicTaskService()

    init(settings: Settings) {
        self.settings = settings
        periodicTaskService.chatViewModel = self // ссылка для добавления сообщений
    }

    // В sendToClaudeDirectly добавляем tools
    let periodicTools = PeriodicTaskToolsProvider.getTools()
    tools.append(contentsOf: periodicTools)

    // В handleToolUse добавляем обработку
    if toolName == "start_weather_updates" {
        let result = PeriodicTaskToolsProvider.executeTool(
            name: toolName,
            input: toolInput,
            periodicTaskService: periodicTaskService
        )
        // Add to toolResults...
    }
}
```

---

## 🎬 Готово! Тестируем

### 1. Соберите проект

```bash
# MCP Weather Server
cd mcp-weather-server
npm run build

# Swift App
cd ..
xcodebuild -project AIAdventChatV2.xcodeproj -scheme AIAdventChatV2 build
```

### 2. Запустите приложение

### 3. В чате напишите:

```
"Присылай мне погоду в Москве каждый час"
```

### 4. Claude ответит:

```
✅ Буду присылать погоду в Москве каждые 60 минут!
Первое обновление отправлю прямо сейчас.
```

### 5. Сразу же появится:

```
🤖 Погодный агент • 14:23

🌤️ Погода в Москве:
• Температура: +15°C
• Состояние: переменная облачность
• Ветер: 5 м/с
• Влажность: 65%
```

### 6. Через час автоматически:

```
🤖 Погодный агент • 15:23

🌤️ Погода в Москве:
• Температура: +16°C
• Состояние: ясно
• Ветер: 3 м/с
• Влажность: 60%
```

---

## 🔧 Полезные команды

### Остановить обновления:

```
"Останови обновления погоды"
```

### Изменить интервал:

```
"Присылай погоду каждые 30 минут"
```

### Другой город:

```
"Переключись на погоду в Санкт-Петербурге"
```

---

## 🐛 Troubleshooting

### "Weather service not connected"

```bash
# Проверьте что MCP сервер собран
ls mcp-weather-server/build/index.js

# Если нет, соберите
cd mcp-weather-server
npm run build
```

### "Invalid API key"

```bash
# Проверьте .env файл
cat mcp-weather-server/.env

# Получите новый ключ
# https://openweathermap.org/api
```

### Таймер не работает

```swift
// Убедитесь что PeriodicTaskService НЕ освобождается
// В ChatViewModel держите strong reference:
private let periodicTaskService = PeriodicTaskService()
```

---

## 📊 Что дальше?

### Расширения:

1. **Несколько задач** - добавьте массив задач вместо одной
2. **Persistence** - сохраняйте задачи в UserDefaults
3. **UI** - создайте список активных задач
4. **Другие источники** - Yandex Tracker stats, курсы валют, новости

### Примеры других задач:

```swift
// Статистика Tracker каждое утро в 9:00
"Присылай статистику задач каждое утро в 9:00"

// Курс доллара каждые 4 часа
"Показывай курс доллара каждые 4 часа"

// Напоминание о встрече
"Напомни о встрече через 2 часа"
```

---

## ✅ Итого

**Время реализации:** 2-3 часа
**Сложность:** Средняя
**Результат:** Работающий периодический агент!

🎉 **Готово к использованию!**
