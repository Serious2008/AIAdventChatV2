# RAG Chat с историей диалога - Реализация

## ✅ Что реализовано

### 1. **Новый метод в RAGService** (RAGService.swift:284-444)

#### `answerWithHistory()` - основной метод
Отвечает на вопросы с учётом:
- Векторного поиска по документам
- Истории предыдущих сообщений (последние 5)
- Обязательных цитат из источников

**Ключевые особенности:**
- Принимает `history: [Message]` - массив предыдущих сообщений
- Использует reranking для фильтрации релевантных документов
- Автоматически валидирует наличие цитат
- Retry логика (до 2 попыток) если цитаты отсутствуют

**Пример вызова:**
```swift
let response = try await ragService.answerWithHistory(
    question: "Как работает суммаризация?",
    history: previousMessages,
    topK: 5,
    rerankingStrategy: .threshold(0.5),
    maxAttempts: 2
)
```

#### Вспомогательные методы:

**`buildHistoryContext()`** - форматирует историю
```swift
private func buildHistoryContext(history: [Message]) -> String {
    // Берёт последние 5 сообщений
    // Форматирует как "[Пользователь/Ассистент - время]: текст"
}
```

**`buildRAGPromptWithHistory()`** - создаёт промпт
```swift
private func buildRAGPromptWithHistory(
    question: String,
    documentContext: String,
    historyContext: String
) -> String {
    // Объединяет:
    // - Контекст из документов
    // - Историю диалога
    // - Текущий вопрос
    // - Требования к цитированию
}
```

---

### 2. **Обновлённая модель Message** (Message.swift:16-29)

Добавлены поля для хранения RAG метаданных:

```swift
struct RAGSource: Codable, Identifiable {
    let id: UUID
    let fileName: String
    let similarity: Double
    let chunkContent: String
}

struct Message: Identifiable, Codable {
    // ... существующие поля ...

    // RAG metadata
    var usedRAG: Bool = false
    var ragSources: [RAGSource]? = nil
    var citationCount: Int? = nil
}
```

**Зачем это нужно:**
- `usedRAG` - флаг, что ответ получен через RAG
- `ragSources` - список файлов, использованных для ответа
- `citationCount` - количество цитат в ответе

---

### 3. **Новый метод в ChatViewModel** (ChatViewModel.swift:1994-2084)

#### `sendMessageWithRAG(enableRAG: Bool)` - отправка с RAG

**Алгоритм:**
1. Проверяет настройки и API ключ
2. Создаёт сообщение пользователя
3. Если `enableRAG == true`:
   - Получает историю (все предыдущие сообщения)
   - Вызывает `ragService.answerWithHistory()`
   - Валидирует цитаты
   - Конвертирует `SearchResult` → `RAGSource`
   - Создаёт сообщение с RAG метаданными
4. Если `enableRAG == false`:
   - Использует обычный метод `sendToClaudeDirectly()`

**Пример создания сообщения с RAG:**
```swift
let assistantMessage = Message(
    content: response.answer,
    isFromUser: false,
    temperature: self.settings.temperature,
    metrics: (
        responseTime: response.processingTime,
        inputTokens: nil,
        outputTokens: nil,
        cost: nil,
        modelName: "claude-3-7-sonnet-20250219"
    ),
    usedRAG: true,
    ragSources: ragSources,
    citationCount: validation.citationCount
)
```

---

### 4. **Обновлённый UI в ChatView** (ChatView.swift:247-328)

#### RAG Toggle - переключатель режима
```swift
@State private var enableRAG = false

Toggle(isOn: $enableRAG) {
    HStack(spacing: 6) {
        Image(systemName: enableRAG ? "doc.text.magnifyingglass.fill" : "doc.text.magnifyingglass")
            .foregroundColor(enableRAG ? .green : .gray)
        Text(enableRAG ? "RAG включён" : "RAG выключен")
            .font(.caption)
            .foregroundColor(enableRAG ? .green : .secondary)
    }
}
```

**Визуальные индикаторы:**
- Когда RAG включён: показывается зелёная иконка и текст "Ответы с цитатами из кодовой базы"
- Кнопка Send меняет цвет: синий (обычный режим) → зелёный (RAG режим)

#### Обновлённая кнопка отправки
```swift
Button(action: {
    if enableRAG {
        viewModel.sendMessageWithRAG(enableRAG: true)
    } else {
        viewModel.sendMessage()
    }
}) {
    HStack(spacing: 4) {
        if enableRAG {
            Image(systemName: "doc.text.magnifyingglass")
        }
        Image(systemName: "paperplane.fill")
    }
    .foregroundColor(canSendMessage ? (enableRAG ? .green : .blue) : .gray)
}
```

---

### 5. **Компонент RAGSourcesView** (MessageBubble.swift:414-518)

Новый UI компонент для отображения источников в сообщениях.

**Возможности:**
- Разворачиваемый список источников
- Badge с количеством цитат
- Badge с количеством файлов
- Для каждого источника:
  - Номер `[1]`, `[2]`, ...
  - Название файла
  - Similarity score (%)
  - Превью контента (первые 100 символов)

**Интеграция:**
Автоматически отображается в MessageBubble если:
```swift
if message.usedRAG, let ragSources = message.ragSources, !ragSources.isEmpty {
    RAGSourcesView(sources: ragSources, citationCount: message.citationCount ?? 0)
}
```

**Внешний вид:**
- Зелёная рамка и фон
- Кликабельный заголовок
- Collapsed: показывает только badge'ы
- Expanded: показывает полный список источников

---

## 🧪 Как тестировать

### Шаг 1: Индексация документов
1. Откройте вкладку **"Search"**
2. Укажите путь к проекту (например, `/Users/you/MyProject`)
3. Выберите типы файлов (Swift, Markdown)
4. Нажмите **"Index Directory"**
5. Дождитесь: "✅ X documents, Y chunks indexed"

### Шаг 2: Включите RAG режим
1. Откройте вкладку **"Чат"**
2. Внизу найдите переключатель **"RAG выключен"**
3. Переключите его → должно стать **"RAG включён"** (зелёный)
4. Появится текст: "Ответы с цитатами из кодовой базы"

### Шаг 3: Задайте вопрос
Примеры вопросов:
- "Как работает векторный поиск?"
- "Где сохраняются сообщения чата?"
- "Какие MCP серверы поддерживаются?"
- "Объясни как реализована суммаризация"
- "Что делает EmbeddingService?"

### Шаг 4: Проверьте ответ

**Ожидается:**
1. Ответ содержит маркеры `[Источник 1]`, `[Источник 2]`
2. Есть секция "Источники:" в конце
3. Есть цитаты кода в блоках \`\`\`swift
4. Под ответом показывается **"RAG Источники"** с badge'ами
5. Нажав на "RAG Источники" можно развернуть список файлов

### Шаг 5: Проверьте историю

Задайте несколько связанных вопросов:
1. "Как работает векторный поиск?"
2. "А какие алгоритмы он использует?" ← должен учесть предыдущий ответ
3. "Покажи пример кода" ← должен понять контекст

**RAG с историей должен:**
- Понимать местоимения ("он", "его", "это")
- Учитывать предыдущие вопросы
- Продолжать тему без повтора контекста

---

## 📊 Пример диалога с RAG

### Вопрос 1:
```
Пользователь: Как работает векторный поиск?
```

### Ответ 1 (с RAG):
```
Векторный поиск реализован в классе VectorSearchService [Источник 1].

Основной метод search(query:topK:) [Источник 1] выполняет следующие шаги:

1. Создаёт эмбеддинг для query через EmbeddingService [Источник 2]:
```swift
let queryEmbedding = try await embeddingService.embed(text: query)
```

2. Вычисляет cosine similarity с каждым чанком [Источник 1]:
```swift
let similarity = cosineSimilarity(queryEmbedding, chunkEmbedding)
```

3. Сортирует результаты по similarity и возвращает топ-K [Источник 1].

Источники:
[1] VectorSearchService.swift - реализация векторного поиска
[2] EmbeddingService.swift - создание эмбеддингов
```

**В UI отображается:**
- ✅ Маркеры: [Источник 1], [Источник 2]
- ✅ Секция "Источники:"
- ✅ Блоки кода
- ✅ **RAG Источники**: 🔖3  📄2 (можно развернуть)

### Вопрос 2 (продолжение):
```
Пользователь: А какой алгоритм similarity используется?
```

### Ответ 2 (RAG учитывает историю):
```
Для вычисления similarity используется **cosine similarity** [Источник 1].

Формула реализована в методе cosineSimilarity(_:_:):
```swift
func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
    let dotProduct = zip(a, b).map(*).reduce(0, +)
    let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
    let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
    return dotProduct / (magnitudeA * magnitudeB)
}
```

Cosine similarity возвращает значение от -1 до 1, где:
- 1 = идентичные векторы
- 0 = ортогональные векторы
- -1 = противоположные векторы

Источники:
[1] VectorSearchService.swift - реализация cosine similarity
```

**RAG понял:**
- Местоимение "какой алгоритм" = про similarity из предыдущего ответа
- Контекст разговора (векторный поиск)
- Не нужно повторять что такое VectorSearchService

---

## 🎯 Преимущества реализации

### 1. RAG + История = Контекстуальный диалог
- Модель "помнит" предыдущие вопросы
- Понимает местоимения и ссылки на предыдущие темы
- Не нужно повторять контекст в каждом вопросе

### 2. Обязательные цитаты = Нет галлюцинаций
- Каждый факт имеет `[Источник N]`
- Можно проверить правдивость утверждений
- Секция "Источники:" в конце каждого ответа

### 3. Визуальные источники = Прозрачность
- Видно какие файлы использовались
- Видно similarity score (релевантность)
- Можно развернуть и прочитать чанки

### 4. Гибкий переключатель = Удобство
- Можно включить/выключить RAG в любой момент
- Обычный режим: быстрые общие ответы
- RAG режим: точные ответы с цитатами из кода

### 5. Reranking + Retry = Качество
- Автоматическая фильтрация нерелевантных документов
- Retry если цитаты не появились
- Threshold 0.5 = хороший баланс

---

## 📈 Сравнение: До и После

### До (обычный чат):
```
Вопрос: Как работает векторный поиск?

Ответ:
"Векторный поиск использует эмбеддинги для нахождения похожих документов.
Он преобразует текст в векторы и вычисляет косинусную близость."

❌ Нет ссылок на код
❌ Нет цитат
❌ Невозможно проверить
❌ Может содержать галлюцинации
❌ Не учитывает историю
```

### После (RAG с историей):
```
Вопрос 1: Как работает векторный поиск?

Ответ:
"Векторный поиск реализован в классе VectorSearchService [Источник 1].
Основной метод search(query:topK:) выполняет..."

✅ Ссылки на файлы
✅ Цитаты кода
✅ Можно проверить каждый факт
✅ Показаны источники
✅ Видно similarity scores

Вопрос 2: А какой алгоритм используется?

Ответ:
"Используется cosine similarity [Источник 1]..."
(понял контекст из предыдущего вопроса)

✅ Учитывает историю диалога
✅ Понимает местоимения
```

---

## 🔧 Технические детали

### Обработка истории:
```swift
// Берём последние 5 сообщений
let recentHistory = Array(history.suffix(5))

// Форматируем
for message in recentHistory {
    let role = message.isFromUser ? "Пользователь" : "Ассистент"
    let timestamp = formatTimestamp(message.timestamp)
    context += """
    [\(role) - \(timestamp)]:
    \(message.displayText)

    """
}
```

### Промпт с историей:
```
Ты - AI ассистент, который помогает разработчикам понять их код.

КРИТИЧЕСКИ ВАЖНО - ОБЯЗАТЕЛЬНЫЕ ТРЕБОВАНИЯ:
1. Используй информацию из КОНТЕКСТА КОДОВОЙ БАЗЫ и ИСТОРИИ ДИАЛОГА
2. ОБЯЗАТЕЛЬНО указывай [Источник N] после КАЖДОГО утверждения из кодовой базы
3. Включай прямые цитаты кода в блоках ```
4. В конце ответа добавь секцию "Источники:" со списком всех использованных файлов

КОНТЕКСТ ИЗ КОДОВОЙ БАЗЫ:
[Источник 1: VectorSearchService.swift - 85%]
class VectorSearchService { ... }

ИСТОРИЯ ПРЕДЫДУЩЕГО ДИАЛОГА:
[Пользователь - 12:30]: Как работает векторный поиск?
[Ассистент - 12:31]: Векторный поиск реализован в VectorSearchService...

ВОПРОС ПОЛЬЗОВАТЕЛЯ:
А какие алгоритмы он использует?
```

### Валидация цитат:
```swift
let validation = validateCitations(response.answer)

// Проверяет:
validation.hasSourceMarkers    // [Источник N]
validation.hasSourcesSection   // "Источники:"
validation.hasFileReferences   // .swift, .md
validation.hasCodeBlocks       // ```
validation.citationCount       // >= 1

if validation.isValid {
    // Отлично! Цитаты есть
} else {
    // Retry: попытка 2
}
```

---

## 📝 Изменённые файлы

### Modified:
1. **RAGService.swift**
   - ✅ Добавлен `answerWithHistory()` (строки 284-363)
   - ✅ Добавлен `buildHistoryContext()` (строки 367-387)
   - ✅ Добавлен `buildRAGPromptWithHistory()` (строки 389-437)
   - ✅ Добавлен `formatTimestamp()` (строки 439-444)

2. **Message.swift**
   - ✅ Добавлена структура `RAGSource` (строки 17-29)
   - ✅ Добавлены поля `usedRAG`, `ragSources`, `citationCount` (строки 46-48)
   - ✅ Обновлены оба инициализатора

3. **ChatViewModel.swift**
   - ✅ Добавлен метод `sendMessageWithRAG()` (строки 1994-2084)

4. **ChatView.swift**
   - ✅ Добавлена переменная `@State enableRAG` (строка 16)
   - ✅ Добавлен RAG Toggle UI (строки 247-275)
   - ✅ Обновлена кнопка отправки (строки 306-325)

5. **MessageBubble.swift**
   - ✅ Добавлена интеграция RAGSourcesView (строки 230-232, 363-365)
   - ✅ Добавлен компонент `RAGSourcesView` (строки 414-518)

### Created:
6. **RAG_CHAT_IMPLEMENTATION.md** (этот файл)

---

## ✅ Готово к использованию!

Запустите приложение и:
1. Проиндексируйте код на вкладке **"Search"**
2. Включите RAG toggle на вкладке **"Чат"**
3. Задайте вопрос про код
4. Получите ответ с цитатами и источниками
5. Продолжите диалог - RAG будет учитывать историю

**Результат:** Чат-бот с RAG-памятью и обязательными ссылками на источники! 🎯
