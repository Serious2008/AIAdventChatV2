# День 4: Сравнение локальной модели vs Claude

> Задача: добавить виджет погоды рядом с заголовком чата, данные из WeatherService

## Конфигурация локальной модели

- **Модель:** phi4:14b (9.1 GB, Q4 квантизация)
- **Инструмент:** Continue (VS Code плагин)
- **Автокомплит:** qwen2.5-coder:1.5b-base
- **Параметры:** temperature 0.1, top_p 0.95, contextLength 8192
- **Правила:** `/swift` slash-команда (~/.continue/prompts/swift.prompt)

---

## Что сгенерировала локальная модель (phi4:14b)

```swift
// ❌ Выдумала несуществующий API
URL(string: "https://api.weather.com/data")

// ❌ Создаёт сервис прямо в View — нарушение DI
let service = WeatherService(settings: Settings())

// ❌ Task в init() — не работает в SwiftUI, @State не обновится
init() {
    Task { self.weatherData = ... }
}

// ❌ Поверхностная модель без реальной структуры API
struct WeatherModel: Identifiable, Codable {
    let temperature: Double
    let description: String
}
```

**Проблемы:**
- Выдумала несуществующий URL вместо реального OpenWeatherMap API
- Нарушила DI — сервис создаётся внутри View
- `Task {}` в `init()` — антипаттерн SwiftUI
- Упрощённая модель данных не соответствует реальному API
- Зависла на этапе `Applying` (Apply слишком медленный для 14B модели)

---

## Что сгенерировал Claude (День 1)

```swift
// ✅ Реальный OpenWeatherMap API
// ✅ Полная модель с вложенными структурами
struct WeatherData: Codable {
    let name: String
    let main: Main        // temp, feels_like, humidity, pressure
    let weather: [Weather]
    let wind: Wind
}

// ✅ Загрузка через .onAppear, не init()
.onAppear { loadWeather() }

// ✅ Три состояния UI
if isLoading { ProgressView() }
else if let weather = weatherData { /* виджет */ }
else if loadError { /* кнопка retry */ }

// ✅ Иконки и цвета по условию погоды
// ✅ Tooltip с подробностями при наведении
// ✅ Tap для ручного обновления
// ✅ #Preview
```

---

## Итоговое сравнение

| Критерий | phi4:14b | Claude |
|---|---|---|
| Рабочий API | ❌ выдуман | ✅ OpenWeatherMap |
| Следование правилам проекта | ⚠️ 80% | ✅ 100% |
| Архитектура MVVM | ⚠️ частично | ✅ полностью |
| Состояния UI (loading/data/error) | ❌ только 2 | ✅ все 3 |
| SwiftUI паттерны | ❌ Task в init | ✅ .onAppear |
| Детализация UI | ❌ минимальная | ✅ иконки, цвета, tooltip, retry |
| Справилась с первого раза | ⚠️ завис Apply | ✅ да |
| Скорость генерации | ❌ медленно (~30-60с) | ✅ быстро (~5-10с) |
| Стоимость | ✅ бесплатно | 💰 API токены |
| Приватность данных | ✅ локально | ⚠️ облако |

---

---

## Тест агентного режима: Bug Fix профиль

> Задача: исправить баг с потоками в WeatherService

### Ответ phi4:14b (/bugfix профиль)

**Диагностика:** "DispatchQueue.main.async потенциально блокирует главный поток" — **неверно**. `DispatchQueue.main.async` не блокирует, это корректное асинхронное переключение на UI поток.

**Фикс локальной модели:**
```swift
// ДО (нормальный код):
DispatchQueue.main.async { completion(.failure(error)) }

// ПОСЛЕ ("исправление" локальной модели):
DispatchQueue.global().async {
    DispatchQueue.main.async { completion(.failure(error)) }
}
```
Результат — **регресс**: лишняя обёртка `global().async` вокруг уже асинхронного кода. Бесполезное переключение потоков без цели.

### Ответ Claude (День 1)

**Диагностика:** Реальный баг — `process.waitUntilExit()` в `LocalModelService` вызывался синхронно на главном потоке, замораживая UI.

**Фикс:**
```swift
// Обернул waitUntilExit() в фоновую очередь
DispatchQueue.global(qos: .userInitiated).async {
    process.waitUntilExit()
    DispatchQueue.main.async {
        completion(.success(...))
    }
}
```

### Сравнение Bug Fix

| Критерий | phi4:14b | Claude |
|---|---|---|
| Нашёл правильный баг | ❌ неверная причина | ✅ точно |
| Фикс рабочий | ❌ регресс | ✅ да |
| Emoji логирование | ❌ не добавил | ✅ |
| Проверил зависимости | ⚠️ формально | ✅ реально |
| Формат ответа (bugfix профиль) | ✅ структура есть | ✅ |

**Вывод:** Локальная модель корректно использует формат `/bugfix` профиля, но диагноз неверный, а фикс ухудшает код. Агентный режим для Bug Fix требует облачной модели.

---

## Выводы

**Локальная модель подходит для:**
- Автокомплит кода (qwen2.5-coder:1.5b быстро и точно)
- Простые вопросы по синтаксису Swift
- Рефакторинг небольших фрагментов кода
- Задачи где важна приватность

**Локальная модель не справляется с:**
- Точным следованием архитектурным правилам проекта
- Генерацией кода с реальными внешними API
- Агентным режимом (Apply зависает)
- Сложными многофайловыми задачами

**Оптимальная конфигурация:**
- Chat: phi4:14b или облачная модель для сложных задач
- Autocomplete: qwen2.5-coder:1.5b-base (локально, быстро)
- Apply: qwen2.5-coder:1.5b-base (небольшие правки)

---

## Тест агентного режима: Research профиль

> Задача: какие эндпоинты (URL) не покрыты тестами?

### Ответ phi4:14b (/research профиль)

Модель **не открыла ни одного файла** проекта. Ответила абстрактным шаблоном с несуществующими файлами:
- Упомянула `APIController.swift` — файла не существует
- Упомянула `APITests.swift` — файла не существует
- Показала гипотетический код `testGetUsers()` — которого нет в проекте

### Ответ Claude (реальный research)

**📁 Реальные эндпоинты найдены в коде:**

| Сервис | Эндпоинт |
|---|---|
| `ClaudeService.swift` | `https://api.anthropic.com/v1/messages` |
| `EmbeddingService.swift` | `https://api.openai.com/v1/embeddings` |
| `HuggingFaceService.swift` | `https://router.huggingface.co/v1/chat/completions` |
| `WeatherService.swift` | `https://api.openweathermap.org/data/2.5/weather` |
| `OllamaService.swift` | `http://localhost:11434/api/tags`, `/api/generate` |

**⚠️ Все 7 эндпоинтов не покрыты тестами** — в `AIAdventChatV2Tests/` ни одного URL, ни мока, ни реального вызова.

### Сравнение Research агента

| Критерий | phi4:14b | Claude |
|---|---|---|
| Открыла реальные файлы проекта | ❌ нет | ✅ да |
| Нашла реальные URL | ❌ выдумала файлы | ✅ 7 реальных эндпоинтов |
| Проверила тестовые файлы | ❌ нет | ✅ да, 0 покрытия URL |
| Ответила по реальному коду | ❌ шаблон | ✅ конкретные файлы и строки |
| Формат ответа (research профиль) | ✅ структура есть | ✅ |

**Вывод:** Research агент на локальной модели без индексации кодовой базы бесполезен для вопросов о конкретном коде. Модель отвечает по памяти, игнорируя реальные файлы проекта.
