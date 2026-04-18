---
description: Создает новый Service в проекте AIAdventChatV2 по всем правилам
---

ВАЖНО: Сначала прочитай файл CLAUDE.md в корне проекта для понимания правил и паттернов!

ЗАДАЧА: Создать новый Service класс для проекта AIAdventChatV2

КОНТЕКСТ ПРОЕКТА:
- Проект: macOS приложение на Swift/SwiftUI
- Архитектура: MVVM
- Правила проекта: см. CLAUDE.md

ЗАПРОСИ У ПОЛЬЗОВАТЕЛЯ:
1. Название сервиса (например: "Weather" для WeatherService)
2. Назначение сервиса (что он делает)
3. Нужен ли Settings в качестве dependency?

ЗАТЕМ АВТОМАТИЧЕСКИ:

**ШАГ 1: Прочитай CLAUDE.md**
Изучи секцию про Services и шаблон файла

**ШАГ 2: Создай файл**
Создай файл в `AIAdventChatV2/Services/{Название}Service.swift`

**ШАГ 3: Используй правильный шаблон**
```swift
//
//  {Название}Service.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on {текущая дата}.
//

import Foundation

class {Название}Service {
    // MARK: - Properties

    private let settings: Settings

    // MARK: - Initialization

    init(settings: Settings) {
        self.settings = settings
        print("🚀 {Название}Service initialized")
    }

    // MARK: - Public Methods

    func performAction() async throws -> Result {
        print("📤 {Название}Service: Starting action...")
        // TODO: Implement logic
        print("✅ {Название}Service: Action completed")
        return Result()
    }

    // MARK: - Private Methods

    private func helperMethod() {
        // Implementation
    }
}

// MARK: - Supporting Types

struct Result: Codable {
    // Define result structure
}
```

**ШАГ 4: Напомни о следующих шагах**
После создания файла напомни пользователю:
- ✅ Файл создан в Services/
- ⚠️ Нужно добавить сервис в ChatViewModel как dependency
- ⚠️ Реализовать бизнес-логику в методах
- ⚠️ Протестировать компиляцию

**ВАЖНЫЕ ПРАВИЛА:**
- Используй MARK: комментарии
- Добавляй emoji в print statements (🚀, ✅, ❌, 📤, 📥)
- Settings через dependency injection
- Async/await для асинхронных операций
- Codable типы для моделей данных
- Error handling через Result или throws
