---
description: Создает новую Model в проекте AIAdventChatV2 по всем правилам
---

ВАЖНО: Сначала прочитай файл CLAUDE.md в корне проекта для понимания правил и паттернов!

ЗАДАЧА: Создать новую Model структуру для проекта AIAdventChatV2

КОНТЕКСТ ПРОЕКТА:
- Проект: macOS приложение на Swift/SwiftUI
- Архитектура: MVVM
- Все модели должны быть Codable + Identifiable
- Правила проекта: см. CLAUDE.md

ЗАПРОСИ У ПОЛЬЗОВАТЕЛЯ:
1. Название модели (например: "WeatherData")
2. Основные поля (id, title, date и т.д.)
3. Нужны ли вложенные типы?

ЗАТЕМ АВТОМАТИЧЕСКИ:

**ШАГ 1: Прочитай CLAUDE.md**
Изучи секцию про Models и примеры хорошего кода

**ШАГ 2: Создай файл**
Создай файл в `AIAdventChatV2/Models/{Название}.swift`

**ШАГ 3: Используй правильный шаблон**
```swift
//
//  {Название}.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on {текущая дата}.
//

import Foundation

struct {Название}: Identifiable, Codable, Equatable {
    // MARK: - Properties

    let id: UUID
    let title: String
    let createdAt: Date
    var metadata: Metadata?

    // MARK: - Nested Types

    struct Metadata: Codable, Equatable {
        let source: String
        let confidence: Double?
    }

    // MARK: - Initializers

    // Convenience initializer
    init(title: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.metadata = nil
    }

    // Full initializer for database restoration
    init(
        id: UUID,
        title: String,
        createdAt: Date,
        metadata: Metadata? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.metadata = metadata
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        !title.isEmpty
    }
}

// MARK: - Default Values

extension {Название} {
    static let empty = {Название}(title: "")

    static let example = {Название}(
        title: "Example",
        // ...
    )
}
```

**ШАГ 4: Проверь соответствие правилам**
- ✅ Identifiable (есть id: UUID)
- ✅ Codable (для JSON сериализации)
- ✅ Equatable (для сравнения)
- ✅ MARK: комментарии
- ✅ Два initializer'а (convenience + full)
- ✅ Computed properties для валидации
- ✅ Вложенные типы (если нужны)

**ШАГ 5: Напомни о следующих шагах**
После создания файла напомни пользователю:
- ✅ Файл создан в Models/
- ⚠️ Добавить модель в ViewModel если нужно
- ⚠️ Создать DatabaseManager методы если нужна персистентность
- ⚠️ Протестировать компиляцию

**ВАЖНЫЕ ПРАВИЛА:**
- Всегда Identifiable + Codable
- let для неизменяемых полей
- var для опциональных/изменяемых полей
- UUID для id (не Int)
- Date для timestamp
- Вложенные типы внутри основной структуры
- Extension для static examples
