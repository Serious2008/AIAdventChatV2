# ДЕМО: Как работает /analyze-project

## Обнаруженная структура проекта:

```
AIAdventChatV2/
├── 📱 App Entry Point
│   └── AIAdventChatV2App.swift
│
├── 📊 Models (3 файла)
│   ├── Message.swift
│   ├── Settings.swift
│   ├── ClaudeTool.swift
│   └── PeriodicTask.swift
│
├── 🎨 Views (13 файлов)
│   ├── ContentView.swift
│   ├── ChatView.swift
│   ├── SettingsView.swift
│   ├── MessageBubble.swift
│   ├── TokenIndicatorView.swift
│   ├── GeneratedDocumentView.swift
│   ├── MCPView.swift
│   ├── MCPTestView.swift
│   ├── YandexTrackerTestView.swift
│   └── MultiAgent/
│       ├── MultiAgentView.swift
│       ├── AgentResultCard.swift
│       ├── ImplementationCard.swift
│       ├── PlanCard.swift
│       ├── ResultView.swift
│       └── Helper/
│           ├── MetricBadge.swift
│           └── SectionView.swift
│
├── 🎯 ViewModels (2 файла)
│   ├── ChatViewModel.swift
│   └── ChatViewModel+YandexTracker.swift (extension)
│
└── 🔧 Services (15 файлов)
    ├── ClaudeService.swift
    ├── MCPService.swift
    ├── SimulatorService.swift
    ├── SimulatorTools.swift
    ├── YandexTrackerService.swift
    ├── YandexTrackerAgent.swift
    ├── YandexTrackerTools.swift
    ├── PeriodicTaskService.swift
    ├── PeriodicTaskTools.swift
    ├── WeatherService.swift
    ├── HuggingFaceService.swift
    ├── LocalModelService.swift
    ├── MultiAgentService.swift
    ├── SolverReviewerService.swift
    └── TokenManager.swift
```

**Всего:** 37 Swift файлов

## Архитектура

**Паттерн:** MVVM (Model-View-ViewModel)

**Основные компоненты:**

1. **Core Services:**
   - `ClaudeService` - работа с Claude API
   - `MCPService` - Model Context Protocol для расширений

2. **Integration Services:**
   - `YandexTrackerService` - интеграция с Yandex Tracker
   - `SimulatorService` - управление iOS симулятором
   - `PeriodicTaskService` - периодические задачи

3. **AI Services:**
   - `MultiAgentService` - мультиагентная система
   - `SolverReviewerService` - решение и ревью
   - `HuggingFaceService` - работа с HuggingFace моделями
   - `LocalModelService` - локальные модели

4. **Tools Providers:**
   - `YandexTrackerTools` - инструменты для трекера
   - `SimulatorTools` - инструменты для симулятора
   - `PeriodicTaskTools` - инструменты для задач

## Когда вы выполните /analyze-project

Команда выполнит полный анализ и предоставит:

### 1. Детальную структуру
- Все файлы с описанием их назначения
- Зависимости между модулями
- Граф взаимодействия компонентов

### 2. Анализ архитектурных паттернов
- MVVM реализация
- Использование Combine/async-await
- Dependency injection паттерны

### 3. Поиск проблем
- Memory leaks (retain cycles)
- Force unwrapping (`!`)
- Missing error handling
- Threading issues
- Hardcoded values

### 4. Code quality metrics
- Соблюдение Swift style guide
- Использование современных API
- Тестовое покрытие (если есть тесты)

### 5. Конкретные рекомендации
- Что рефакторить
- Где добавить тесты
- Как улучшить производительность

## Пример использования

### В вашем приложении AIAdventChatV2:

1. Откройте чат
2. Введите: `/analyze-project`
3. Дождитесь анализа (может занять 1-2 минуты)
4. Получите подробный отчет

### Альтернативно - прямой запрос:

Вместо команды можете написать в чате:

```
Проанализируй весь проект AIAdventChatV2:
1. Построй структуру
2. Найди потенциальные баги
3. Дай рекомендации по улучшению
```

## Примеры запросов для более детального анализа

После первичного анализа можете задавать уточняющие вопросы:

```
Покажи все места где используется force unwrapping (!)
```

```
Найди все retain cycles в ViewModels
```

```
Где в коде отсутствует обработка ошибок?
```

```
Какие файлы самые большие и сложные?
```

```
Построй граф зависимостей между сервисами
```

## Как это работает технически

1. **Сбор файлов:** Glob находит все .swift файлы
2. **Анализ структуры:** Читает и категоризирует файлы
3. **Поиск паттернов:** Grep ищет типичные проблемы:
   - `!` - force unwrapping
   - `as!` - force casting
   - `@escaping.*\[weak self\]` - проверка weak references
   - `try!` - force try
4. **Генерация отчета:** Структурированный markdown

## Следующие шаги

✅ **Команда создана:** `.claude/commands/analyze-project.md`
✅ **Документация готова:** `ANALYZE_PROJECT_GUIDE.md`
✅ **Демо подготовлено:** `DEMO_ANALYSIS.md`

**Попробуйте прямо сейчас:**
- Запустите приложение AIAdventChatV2
- Введите `/analyze-project` в чате
- Или просто напишите: "Проанализируй проект и найди баги"
