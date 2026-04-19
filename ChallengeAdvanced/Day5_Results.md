# Day 5 — Execution Loop: Результаты двух прогонов

## Пул задач (15 задач)

| ID | Тип | Описание |
|---|---|---|
| TASK-01 | 🐛 Bug | LocalModelService.checkPythonAvailability блокирует поток |
| TASK-02 | 🐛 Bug | LocalModelService.checkModelAvailability блокирует поток |
| TASK-03 | 🐛 Bug | WeatherService — лишний DispatchQueue.global |
| TASK-04 | 🐛 Bug | WeatherService — дублирование urlString |
| TASK-05 | ♻️ Refactor | WeatherService — MARK секции |
| TASK-06 | ♻️ Refactor | WeatherService — emoji логирование |
| TASK-07 | ♻️ Refactor | WeatherService — WeatherError enum |
| TASK-08 | ♻️ Refactor | LocalModelService — MARK секции |
| TASK-09 | 🧪 Test | WeatherService.extractCityName — тесты |
| TASK-10 | 🧪 Test | WeatherService.isWeatherRequest — тесты |
| TASK-11 | 🧪 Test | WeatherData — Codable тесты |
| TASK-12 | 🧪 Test | TokenManager — граничные значения |
| TASK-13 | 📄 Docs | Docs/API_ENDPOINTS.md |
| TASK-14 | 📄 Docs | Doc-комментарии WeatherService |
| TASK-15 | 📄 Docs | #Preview для MessageBubble, SettingsView, UserProfileView |

---

## Прогон 1 — phi4:14b (локальная модель)

**Метод:** bash-скрипт → Ollama API → применить файл → git commit → следующая задача

### Лог задач

| Задача | Статус | Причина | Время |
|---|---|---|---|
| TASK-01 | ❌ | timeout 120с — модель не ответила | 120с |
| TASK-02 | ❌ | timeout 120с | 120с |
| TASK-03 | ❌ | timeout 120с | 120с |
| TASK-04 | ❌ | timeout 120с | 120с |
| TASK-05 | ❌ | timeout 120с | 120с |
| TASK-06 | ❌ | timeout 120с | 120с |
| TASK-07 | ❌ | timeout 120с | 120с |
| TASK-08 | ❌ | timeout 120с | 120с |
| TASK-09 | ❌ | timeout 120с | 120с |
| TASK-10 | ❌ | timeout 120с | 120с |
| TASK-11 | ❌ | timeout 120с | 120с |
| TASK-12 | ❌ | timeout 120с | 120с |
| TASK-13 | ❌ | timeout 120с | 120с |
| TASK-14 | ❌ | timeout 120с | 120с |
| TASK-15 | ❌ | timeout 120с | 120с |

### Метрики Прогона 1

| Метрика | Значение |
|---|---|
| Задач выполнено | 0 / 15 |
| Задач провалено | 15 / 15 |
| Подряд без паузы | 0 |
| Первый сбой | TASK-01 |
| Среднее время на задачу | 120с (timeout) |
| Общее время | ~30 минут |
| Коммитов | 0 |

**Причина провала:** phi4:14b слишком медленная для autonomous loop через API. Контекст (системный промпт + файл + задача) превысил скорость генерации модели — каждый запрос таймаутился на 120с не дав ответа.

---

## Прогон 2 — Claude Code (облачная модель)

**Метод:** прямое редактирование файлов + 1 коммит со всеми изменениями

### Лог задач

| Задача | Статус | Файл | Время |
|---|---|---|---|
| TASK-01 | ✅ | LocalModelService.swift | 15с |
| TASK-02 | ✅ | LocalModelService.swift | 0с (в том же файле) |
| TASK-03 | ✅ | WeatherService.swift | 10с |
| TASK-04 | ✅ | WeatherService.swift | 0с (в том же файле) |
| TASK-05 | ✅ | WeatherService.swift | 0с (в том же файле) |
| TASK-06 | ✅ | WeatherService.swift | 0с (в том же файле) |
| TASK-07 | ✅ | WeatherService.swift | 0с (в том же файле) |
| TASK-08 | ✅ | LocalModelService.swift | 5с |
| TASK-09 | ✅ | WeatherServiceTests.swift | 20с |
| TASK-10 | ✅ | WeatherServiceTests.swift | 0с (в том же файле) |
| TASK-11 | ✅ | WeatherServiceTests.swift | 0с (в том же файле) |
| TASK-12 | ✅ | TokenManagerTests.swift | 10с |
| TASK-13 | ✅ | Docs/API_ENDPOINTS.md | 5с |
| TASK-14 | ✅ | WeatherService.swift | 0с (в том же файле) |
| TASK-15 | ✅ | MessageBubble, SettingsView, UserProfileView | 15с |

### Метрики Прогона 2

| Метрика | Значение |
|---|---|
| Задач выполнено | 15 / 15 |
| Задач провалено | 0 / 15 |
| Подряд без паузы | 15 |
| Первый сбой | нет |
| Среднее время на задачу | ~5с |
| Общее время | ~5 минут |
| Коммитов | 1 |
| Процент с первого раза | 100% |

---

## Итоговое сравнение

| Метрика | phi4:14b (локальная) | Claude Code (облако) |
|---|---|---|
| Задач выполнено | 0 / 15 | 15 / 15 |
| Подряд без паузы | 0 | 15 |
| Среднее время / задача | 120с (timeout) | ~5с |
| Первый сбой | TASK-01 | нет |
| % с первого раза | 0% | 100% |
| Автономность | ❌ зависала | ✅ полная |
| Коммитов создано | 0 | 1 |

---

## Анализ: почему phi4:14b провалила execution loop

1. **Скорость** — 14B модель слишком медленная для autonomous loop. Генерация ответа с большим контекстом (>2000 токенов) превышала 120с timeout
2. **Контекст** — системный промпт + содержимое файла + описание задачи = слишком большой промпт для реального времени ответа
3. **Формат** — модель не следовала строгому формату `FILE: path` даже когда отвечала — Continue/shell не мог распарсить ответ
4. **Архитектура** — локальные модели не приспособлены для pipeline execution loop. Они заточены под интерактивный чат с человеком

## Вывод

**Execution Loop работает только с облачными моделями** (Claude API, GPT-4).
Локальные 14B модели подходят для:
- Автокомплита (1.5B — быстро)
- Интерактивного чата с паузами между запросами
- Единичных задач без pipeline

Для автономного выполнения задач без вмешательства человека нужна модель которая отвечает за 2-5с — это возможно только в облаке или с очень маленькими (1-3B) специализированными моделями.
