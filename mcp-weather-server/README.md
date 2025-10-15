# MCP Weather Server

MCP сервер для получения информации о погоде через OpenWeatherMap API.

## Установка

1. Получите бесплатный API ключ:
   - Зарегистрируйтесь на https://openweathermap.org/api
   - Скопируйте API ключ из раздела API keys

2. Создайте `.env` файл:
   ```bash
   cp .env.example .env
   ```

3. Добавьте ваш API ключ в `.env`:
   ```
   OPENWEATHER_API_KEY=ваш_ключ_здесь
   ```

4. Установите зависимости:
   ```bash
   npm install
   ```

5. Соберите проект:
   ```bash
   npm run build
   ```

## Использование

Сервер предоставляет один инструмент:

### `get_weather_summary`

Получить текущую погоду для указанного города.

**Параметры:**
- `city` (string, обязательный): Название города (например: "Москва", "Санкт-Петербург", "London")

**Пример ответа:**
```
🌤️ Погода в Москве:
• Температура: +15°C (ощущается как +13°C)
• Состояние: переменная облачность
• Ветер: 5 м/с
• Влажность: 65%
• Облачность: 40%
• Давление: 1013 гПа
• Время обновления: 14:23:15
```

## Тестирование

Запустите сервер напрямую:
```bash
node build/index.js
```

Сервер ожидает MCP команды через stdin и отвечает через stdout.

## Интеграция с ChatViewModel

Сервер используется через MCPService в Swift приложении:
```swift
let serverPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Documents/PetProject/AIAdventChatV2/mcp-weather-server/build/index.js")
    .path

try await mcpService.connect(serverCommand: ["node", serverPath])
```
