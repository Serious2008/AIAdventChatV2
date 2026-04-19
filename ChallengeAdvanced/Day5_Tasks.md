# Day 5 — Пул задач для Execution Loop

> Статусы: 🔲 todo | 🔄 in progress | ✅ done | ❌ failed

---

## 🐛 Баги (4)

### TASK-01 — LocalModelService блокирует главный поток (checkPythonAvailability)
**Тип:** Bug  
**Файл:** `Services/LocalModelService.swift`  
**Проблема:** `process.waitUntilExit()` вызывается синхронно на вызывающем потоке  
**Критерий готовности:** `waitUntilExit()` обёрнут в `DispatchQueue.global().async`  
**Статус:** ❌

---

### TASK-02 — LocalModelService блокирует главный поток (checkModelAvailability)
**Тип:** Bug  
**Файл:** `Services/LocalModelService.swift`  
**Проблема:** Та же проблема что в TASK-01, но в методе `checkModelAvailability`  
**Критерий готовности:** `waitUntilExit()` обёрнут в `DispatchQueue.global().async`  
**Статус:** ❌

---

### TASK-03 — WeatherService: лишний DispatchQueue.global в fetchWeatherData
**Тип:** Bug  
**Файл:** `Services/WeatherService.swift`  
**Проблема:** В ветке `guard let data` используется `DispatchQueue.global().async { DispatchQueue.main.async {...} }` — двойное переключение без смысла, достаточно `DispatchQueue.main.async`  
**Критерий готовности:** Убран лишний `DispatchQueue.global().async`, используется только `DispatchQueue.main.async`  
**Статус:** ✅

---

### TASK-04 — WeatherService: дублирование кода построения urlString
**Тип:** Bug/Refactoring  
**Файл:** `Services/WeatherService.swift`  
**Проблема:** `urlString` строится одинаково в `fetchWeatherData` и `fetchWeather` — при изменении параметров нужно менять в двух местах  
**Критерий готовности:** Вынесен приватный метод `buildURL(for city: String) -> URL?`  
**Статус:** ❌

---

## ♻️ Рефакторинг (4)

### TASK-05 — WeatherService: добавить MARK секции
**Тип:** Refactoring  
**Файл:** `Services/WeatherService.swift`  
**Проблема:** Нет `// MARK:` секций — нарушение правил проекта  
**Критерий готовности:** Добавлены `// MARK: - Properties`, `// MARK: - Public Methods`, `// MARK: - Private Methods`  
**Статус:** 🔲

---

### TASK-06 — WeatherService: добавить emoji логирование
**Тип:** Refactoring  
**Файл:** `Services/WeatherService.swift`  
**Проблема:** Нет `print()` с emoji — нарушение правил проекта  
**Критерий готовности:** Добавлены `print("🌤️ ...")`, `print("✅ ...")`, `print("❌ ...")`  
**Статус:** 🔲

---

### TASK-07 — WeatherService: добавить кастомный enum ошибок
**Тип:** Refactoring  
**Файл:** `Services/WeatherService.swift`  
**Проблема:** Используются `NSError` с магическими кодами вместо типизированных ошибок  
**Критерий готовности:** Добавлен `enum WeatherError: LocalizedError` с кейсами `invalidURL`, `noData`, `decodingFailed`  
**Статус:** 🔲

---

### TASK-08 — LocalModelService: добавить MARK секции
**Тип:** Refactoring  
**Файл:** `Services/LocalModelService.swift`  
**Проблема:** 249 строк без единой `// MARK:` секции  
**Критерий готовности:** Код разбит на секции: Properties, Public Methods, Private Methods  
**Статус:** 🔲

---

## 🧪 Тесты (4)

### TASK-09 — Тесты для WeatherService.extractCityName
**Тип:** Test  
**Файл:** создать `AIAdventChatV2Tests/WeatherServiceTests.swift`  
**Проблема:** Метод `extractCityName` не покрыт тестами  
**Критерий готовности:** Минимум 5 тестов: корректный город, нет города, разные паттерны  
**Статус:** 🔲

---

### TASK-10 — Тесты для WeatherService.isWeatherRequest
**Тип:** Test  
**Файл:** `AIAdventChatV2Tests/WeatherServiceTests.swift`  
**Проблема:** Метод `isWeatherRequest` не покрыт тестами  
**Критерий готовности:** Минимум 5 тестов: погодные запросы, не погодные запросы  
**Статус:** 🔲

---

### TASK-11 — Тесты для WeatherData модели
**Тип:** Test  
**Файл:** создать `AIAdventChatV2Tests/WeatherDataTests.swift`  
**Проблема:** Модель `WeatherData` не покрыта тестами  
**Критерий готовности:** Тесты на Codable encode/decode, все вложенные структуры  
**Статус:** 🔲

---

### TASK-12 — Тесты для TokenManager.getLimit по моделям
**Тип:** Test  
**Файл:** `AIAdventChatV2Tests/TokenManagerTests.swift`  
**Проблема:** Нет теста для граничных значений лимитов  
**Критерий готовности:** Добавлены тесты на пустую строку модели и неизвестный провайдер  
**Статус:** 🔲

---

## 📄 Документация (3)

### TASK-13 — Создать API_ENDPOINTS.md
**Тип:** Docs  
**Файл:** создать `Docs/API_ENDPOINTS.md`  
**Проблема:** Нет документации по внешним API которые использует приложение  
**Критерий готовности:** Файл с таблицей всех 5 эндпоинтов: сервис, URL, метод, назначение  
**Статус:** 🔲

---

### TASK-14 — Добавить doc-комментарии к WeatherService
**Тип:** Docs  
**Файл:** `Services/WeatherService.swift`  
**Проблема:** Публичные методы без комментариев  
**Критерий готовности:** `///` комментарии на все public методы с описанием параметров  
**Статус:** 🔲

---

### TASK-15 — Добавить #Preview к Views без Preview
**Тип:** Docs/DX  
**Файлы:** `Views/MessageBubble.swift`, `Views/SettingsView.swift`, `Views/UserProfileView.swift`  
**Проблема:** 7 View-файлов без `#Preview` — нарушение правил проекта  
**Критерий готовности:** `#Preview` добавлен в каждый из трёх файлов  
**Статус:** 🔲
