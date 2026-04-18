# AIAdventChatV2 - Правила проекта для AI-ассистентов

> **Файл создан:** 18.04.2026
> **Проект:** AIAdventChatV2 - Claude AI Chat Application с поддержкой RAG, MCP, векторного поиска и персонализации

---

## 📋 О проекте

**AIAdventChatV2** - macOS приложение для общения с Claude AI и другими LLM-моделями.

**Основные возможности:**
- Чат с Claude AI, HuggingFace и локальными моделями (Ollama)
- RAG (Retrieval-Augmented Generation) с векторным поиском
- Персонализация через профили пользователей
- Интеграция с Yandex Tracker через MCP
- Автоматические тесты и агенты
- Сжатие истории разговоров
- Голосовой ввод (Speech Recognition)
- Долгосрочная память через SQLite

---

## 🛠️ Технологический стек

### Основные технологии
- **Язык:** Swift 6.0
- **UI Framework:** SwiftUI
- **Архитектура:** MVVM (Model-View-ViewModel)
- **Платформа:** macOS 15.5+
- **IDE:** Xcode 16.0+

### Библиотеки и зависимости
- **Foundation** - стандартная библиотека Swift
- **Combine** - реактивное программирование
- **SQLite3** - база данных для долгосрочной памяти
- **AppKit** - нативные macOS API
- **Speech** - распознавание речи
- **MCP** - интеграция с MCP серверами
- **PDFKit** - работа с PDF документами
- **UniformTypeIdentifiers** - работа с типами файлов

### Внешние API
- **Anthropic Claude API** - основная LLM
- **OpenAI API** - для embeddings
- **HuggingFace API** - альтернативные модели
- **Yandex Tracker API** - управление задачами

---

## 📁 Структура проекта

```
AIAdventChatV2/
├── Models/                      # Модели данных (Codable, Identifiable)
│   ├── Message.swift           # Модель сообщения с метриками
│   ├── Settings.swift          # Настройки приложения
│   ├── UserProfile.swift       # Профиль пользователя
│   ├── ClaudeTool.swift        # Инструменты Claude
│   ├── DocumentChunk.swift     # Чанки для RAG
│   ├── PeriodicTask.swift      # Периодические задачи
│   └── ConversationSummary.swift
│
├── ViewModels/                  # Бизнес-логика (ObservableObject)
│   ├── ChatViewModel.swift     # Основная логика чата
│   └── ChatViewModel+YandexTracker.swift
│
├── Views/                       # UI компоненты (SwiftUI)
│   ├── ChatView.swift          # Главный экран чата
│   ├── SettingsView.swift      # Настройки
│   ├── MessageBubble.swift     # Компонент сообщения
│   ├── UserProfileView.swift   # Профиль пользователя
│   ├── AutoTestView.swift      # Автотесты
│   ├── VectorSearchView.swift  # Векторный поиск
│   └── MultiAgent/             # Multi-agent views
│       ├── MultiAgentView.swift
│       └── Helper/
│
├── Services/                    # Сервисы и бизнес-логика
│   ├── ClaudeService.swift     # API интеграция с Claude
│   ├── OllamaService.swift     # Локальные модели
│   ├── DatabaseManager.swift   # SQLite менеджер
│   ├── RAGService.swift        # RAG логика
│   ├── VectorSearchService.swift
│   ├── UserProfileService.swift
│   ├── SpeechRecognitionService.swift
│   ├── YandexTrackerService.swift
│   ├── MCPService.swift
│   └── ...
│
├── Utils/                       # Вспомогательные утилиты
│
├── Assets.xcassets/            # Ресурсы (иконки, цвета)
│
├── ContentView.swift           # Корневой View
└── AIAdventChatV2App.swift     # Главный файл приложения
```

---

## 🎨 Naming Conventions (Соглашения об именовании)

### 1. Сервисы
- **Формат:** `<Название>Service`
- **Примеры:**
  - ✅ `ClaudeService`
  - ✅ `OllamaService`
  - ✅ `RAGService`
  - ✅ `VectorSearchService`
  - ✅ `UserProfileService`
- **Исключения:** `DatabaseManager`, `TokenManager` (менеджеры)

### 2. ViewModels
- **Формат:** `<Название>ViewModel`
- **Примеры:**
  - ✅ `ChatViewModel`
  - ✅ Extensions: `ChatViewModel+YandexTracker.swift`

### 3. Views
- **Формат:** `<Название>View`
- **Примеры:**
  - ✅ `ChatView`
  - ✅ `SettingsView`
  - ✅ `UserProfileView`
  - ✅ `AutoTestView`
- **Исключения:** `MessageBubble`, `ContentView` (специальные компоненты)

### 4. Модели данных
- **Формат:** CamelCase существительное
- **Примеры:**
  - ✅ `Message`
  - ✅ `Settings`
  - ✅ `UserProfile`
  - ✅ `DocumentChunk`
  - ✅ `PeriodicTask`

### 5. Переменные и свойства
- **Формат:** camelCase
- **@Published переменные:**
  - ✅ `isLoading`
  - ✅ `currentMessage`
  - ✅ `errorMessage`
  - ✅ `showingSettings`
- **Private переменные:**
  - ✅ `private let dbQueue`
  - ✅ `private var cancellables`

### 6. Enum'ы
- **Формат:** PascalCase для имени, camelCase для cases
- **Примеры:**
  ```swift
  enum ModelProvider: String, Codable, CaseIterable {
      case claude = "Claude"
      case huggingface = "HuggingFace"
      case local = "LocalLLM (Ollama)"
  }
  ```

### 7. Константы
- **Формат:** camelCase для локальных, PascalCase для глобальных
- **Примеры:**
  - ✅ `private let maxTokensPerMinute = 20000`
  - ✅ `private let baseURL = "http://localhost:11434"`

---

## 📝 Паттерны и Best Practices

### 1. Модели данных

**Обязательные протоколы:**
- `Codable` - для сериализации/десериализации
- `Identifiable` - для SwiftUI списков
- `Equatable` - для сравнения (опционально)

**Структура:**
```swift
struct Message: Identifiable, Codable {
    // MARK: - Properties
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date

    // MARK: - Optional metadata
    var temperature: Double?
    var responseTime: TimeInterval?

    // MARK: - Initializers
    init(content: String, isFromUser: Bool) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
    }

    // Full initializer for database restoration
    init(id: UUID, content: String, isFromUser: Bool, timestamp: Date, ...) {
        self.id = id
        self.content = content
        // ...
    }

    // MARK: - Computed Properties
    var displayText: String {
        // ...
    }
}
```

**✅ Правильно:**
- Использовать `let` для неизменяемых свойств
- Использовать `var` с `?` для опциональных метрик
- Создавать convenience и full initializers
- Группировать свойства по смыслу

**❌ Неправильно:**
- Использовать `Any` вместо конкретных типов
- Хранить чувствительные данные в моделях
- Делать force unwrap без проверки

---

### 2. Сервисы

**Принципы:**
- Dependency Injection через `init`
- Singleton только для глобальных ресурсов (`DatabaseManager.shared`)
- Async/await для асинхронных операций
- Result типы для error handling
- Thread-safe операции с `DispatchQueue`

**Структура:**
```swift
class ClaudeService {
    // MARK: - Properties
    private let maxTokensPerMinute = 20000
    private var tokensUsedInCurrentMinute = 0
    private let rateLimitQueue = DispatchQueue(label: "com.claudeservice.ratelimit")

    // MARK: - Initialization
    init() {
        // Setup
    }

    // MARK: - Public Methods
    func summarize(
        text: String,
        apiKey: String,
        progressCallback: ((String) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Implementation
    }

    // MARK: - Private Methods
    private func splitIntoChunks(_ text: String, maxChunkSize: Int) -> [String] {
        // Implementation
    }
}
```

**✅ Правильно:**
- Использовать `MARK:` комментарии для структурирования
- Emoji в print statements для визуального разделения (`📦`, `✅`, `❌`, `⏰`)
- Использовать `completion handlers` или `async/await`
- Thread-safe доступ к shared state

**❌ Неправильно:**
- Хардкодить API ключи в коде
- Блокировать главный поток
- Использовать глобальные переменные вместо DI

---

### 3. ViewModels

**Принципы:**
- Наследовать от `ObservableObject`
- `@Published` для всех UI-биндингов
- Dependency Injection для сервисов
- Lazy initialization для тяжелых объектов

**Структура:**
```swift
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [Message] = []
    @Published var currentMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    internal let settings: Settings
    private var cancellables = Set<AnyCancellable>()
    private let claudeService = ClaudeService()
    private let dbManager = DatabaseManager.shared

    // Lazy initialization для тяжелых сервисов
    private lazy var compressionService: HistoryCompressionService = {
        HistoryCompressionService(claudeService: claudeService, settings: settings)
    }()

    // MARK: - Initialization
    init(settings: Settings) {
        self.settings = settings
        // Setup
    }

    // MARK: - Public Methods
    func sendMessage() {
        // Implementation
    }

    // MARK: - Private Methods
    private func processMessage() {
        // Implementation
    }
}
```

**✅ Правильно:**
- Использовать `@Published` для UI state
- `internal` или `public` для тестируемых свойств
- Lazy initialization для оптимизации
- Отписываться от Combine subscriptions

**❌ Неправильно:**
- Создавать UI компоненты в ViewModel
- Прямой доступ к UserDefaults (использовать Settings)
- Блокировать главный поток в методах

---

### 4. Views (SwiftUI)

**Принципы:**
- Composition over inheritance
- **Каждый логический UI-блок — отдельная структура в отдельном файле**
- `@ObservedObject` для ViewModels
- `@State` для локального состояния
- `@Environment` для системных параметров

#### 4.1 Декомпозиция на отдельные файлы (ОБЯЗАТЕЛЬНО)

**Правило:** Любой UI-компонент размером >20 строк кода или переиспользуемый в >1 месте **ДОЛЖЕН** быть вынесен в отдельный файл в папке `Views/`.

**Структура файлов для сложного экрана:**
```
Views/
├── ChatView.swift              # Только компоновка (body < 20 строк)
├── ChatHeaderView.swift        # Шапка чата
├── ChatInputBarView.swift      # Поле ввода
├── MessageBubble.swift         # Пузырь сообщения
├── MessageListView.swift       # Список сообщений
└── Components/                 # Мелкие переиспользуемые компоненты
    ├── SendButton.swift
    ├── TypingIndicator.swift
    └── EmptyStateView.swift
```

**Главный экран — только компоновка:**
```swift
// ChatView.swift — ТОЛЬКО компоновка, ноль UI-кода
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(viewModel: viewModel)
            MessageListView(messages: viewModel.messages)
            ChatInputBarView(viewModel: viewModel)
        }
    }
}
```

**Каждый компонент — отдельный файл:**
```swift
// ChatHeaderView.swift
struct ChatHeaderView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.conversationTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("\(viewModel.messages.count) сообщений")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            SettingsButton()
        }
        .padding()
    }
}
```

```swift
// ChatInputBarView.swift
struct ChatInputBarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            TextField("Сообщение...", text: $viewModel.currentMessage)
                .textFieldStyle(.roundedBorder)
            SendButton(isEnabled: !viewModel.currentMessage.isEmpty) {
                viewModel.sendMessage()
            }
        }
        .padding()
    }
}
```

**✅ Правильно:**
- Каждый крупный UI-блок — отдельный `.swift` файл в `Views/`
- `body` главного экрана содержит только встраивание дочерних компонентов
- Переиспользуемые элементы (кнопки, индикаторы) — в `Views/Components/`
- Каждый компонент получает только нужные ему данные через параметры
- `@State` хранится только в том компоненте, которому он принадлежит
- Добавлять `#Preview` к каждому компоненту

**❌ Неправильно:**
- Писать 100+ строк UI-кода в одном файле
- Создавать вложенные struct внутри основного View файла
- Хранить весь UI экрана в одной структуре
- Создавать бизнес-логику в Views
- Прямые обращения к сервисам (через ViewModel)

#### 4.2 Правило разбиения (когда выносить в отдельный файл)

| Условие | Действие |
|---|---|
| Компонент > 20 строк | Отдельный файл |
| Используется в 2+ местах | Отдельный файл в `Components/` |
| Имеет свой `@State` | Отдельный файл |
| Сложная логика отображения | Отдельный файл |
| `body` > 15 строк | Разбить на подкомпоненты |

---

### 5. Database операции (SQLite)

**Принципы:**
- Singleton для DatabaseManager
- Thread-safe операции через DispatchQueue
- Graceful error handling
- Emoji для визуального логирования

**Структура:**
```swift
class DatabaseManager {
    // MARK: - Singleton
    static let shared = DatabaseManager()

    // MARK: - Properties
    private var db: OpaquePointer?
    private let dbPath: String
    private let dbQueue = DispatchQueue(label: "com.aiadventchat.database", qos: .userInitiated)

    // MARK: - Initialization
    private init() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("AIAdventChatV2", isDirectory: true)

        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }

        dbPath = appDirectory.appendingPathComponent("conversations.db").path
        print("📁 Database path: \(dbPath)")

        openDatabase()
        createTables()
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Operations
    private func executeSQL(_ sql: String, errorMessage: String) {
        // Implementation
    }
}
```

**✅ Правильно:**
- Использовать Application Support directory
- Thread-safe операции
- Логировать важные операции с emoji
- Закрывать соединения в deinit

**❌ Неправильно:**
- Хранить DB в временных директориях
- Блокировать главный поток
- Игнорировать ошибки SQLite

---

### 6. Settings и UserDefaults

**Принципы:**
- Централизованный Settings класс
- `@Published` с `didSet` для автосохранения
- Type-safe ключи
- Значения по умолчанию

**Структура:**
```swift
class Settings: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "ClaudeAPIKey")
        }
    }

    @Published var temperature: Double {
        didSet {
            UserDefaults.standard.set(temperature, forKey: "ClaudeTemperature")
        }
    }

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "ClaudeAPIKey") ?? ""
        self.temperature = UserDefaults.standard.object(forKey: "ClaudeTemperature") as? Double ?? 0.7
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }
}
```

**✅ Правильно:**
- Использовать `didSet` для автосохранения
- Проверять типы при чтении из UserDefaults
- Computed properties для валидации

**❌ Неправильно:**
- Прямое использование UserDefaults в других классах
- Хранить пароли в UserDefaults (использовать Keychain)
- Игнорировать опциональные значения

---

## ✅ Примеры хорошего кода из проекта

### Пример 1: Модель с метриками
```swift
struct Message: Identifiable, Codable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date

    // Optional metrics
    var temperature: Double?
    var responseTime: TimeInterval?
    var inputTokens: Int?
    var outputTokens: Int?
    var cost: Double?
    var modelName: String?

    // RAG metadata
    var usedRAG: Bool = false
    var ragSources: [RAGSource]? = nil

    // Convenience initializer
    init(content: String, isFromUser: Bool, metrics: (...)? = nil) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()

        if let metrics = metrics {
            self.responseTime = metrics.responseTime
            self.inputTokens = metrics.inputTokens
            // ...
        }
    }
}
```

**Почему это хорошо:**
- ✅ Четкое разделение на обязательные и опциональные поля
- ✅ Удобный convenience initializer
- ✅ Группировка связанных свойств (RAG metadata)
- ✅ Codable для сериализации

---

### Пример 2: Сервис с dependency injection
```swift
class OllamaService {
    // MARK: - Constants
    private let baseURL = "http://localhost:11434"

    // MARK: - Models
    struct OllamaGenerateRequest: Codable {
        let model: String
        let prompt: String
        let stream: Bool
        let options: Options?

        struct Options: Codable {
            let temperature: Double?
        }
    }

    // MARK: - Check availability
    func checkAvailability(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    completion(httpResponse.statusCode == 200)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
}
```

**Почему это хорошо:**
- ✅ Вложенные модели прямо в сервисе
- ✅ Graceful error handling
- ✅ Timeout для сетевых запросов
- ✅ Main thread для UI updates
- ✅ Early return для читаемости

---

### Пример 3: Персонализация через UserProfile
```swift
struct UserProfile: Codable, Equatable {
    var name: String = ""
    var skills: [String] = []
    var communicationStyle: CommunicationStyle = .balanced

    enum CommunicationStyle: String, Codable, CaseIterable {
        case concise = "Краткий и технический"
        case balanced = "Сбалансированный"
        case detailed = "Подробный с примерами"

        var description: String {
            switch self {
            case .concise:
                return "Краткие технические ответы без лишних деталей"
            case .balanced:
                return "Оптимальный баланс между теорией и практикой"
            case .detailed:
                return "Подробные объяснения с примерами кода"
            }
        }
    }

    func toSystemPrompt() -> String {
        guard isConfigured else { return "" }

        var prompt = "# 👤 О пользователе:\n\n"

        if !name.isEmpty {
            prompt += "- **Имя:** \(name)\n"
        }
        if !skills.isEmpty {
            prompt += "- **Навыки:** \(skills.joined(separator: ", "))\n"
        }

        return prompt
    }
}
```

**Почему это хорошо:**
- ✅ Вложенный enum с описаниями
- ✅ Метод для генерации промпта
- ✅ Валидация через computed property
- ✅ Поддержка CaseIterable для UI пикеров

---

### Пример 4: Async/await с rate limiting
```swift
class ClaudeService {
    private let maxTokensPerMinute = 20000
    private var tokensUsedInCurrentMinute = 0
    private var minuteStartTime = Date()
    private let rateLimitQueue = DispatchQueue(label: "com.claudeservice.ratelimit")

    private func checkAndResetRateLimit() {
        rateLimitQueue.sync {
            let now = Date()
            let timeElapsed = now.timeIntervalSince(minuteStartTime)

            if timeElapsed >= 60 {
                print("⏰ Сброс счетчика токенов: \(tokensUsedInCurrentMinute) за последнюю минуту")
                tokensUsedInCurrentMinute = 0
                minuteStartTime = now
            }
        }
    }

    private func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }
}
```

**Почему это хорошо:**
- ✅ Thread-safe операции с `rateLimitQueue.sync`
- ✅ Логирование с emoji для визуализации
- ✅ Простая эвристика для оценки токенов
- ✅ Автоматический сброс лимитов

---

### Пример 5: SwiftUI computed properties
```swift
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    private var canSendMessage: Bool {
        guard !viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !viewModel.isLoading,
              settings.isConfigured else {
            return false
        }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            messagesList
            inputBar
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.conversationTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if viewModel.messages.count > 0 {
                    Text("\(viewModel.messages.count) сообщений")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
}
```

**Почему это хорошо:**
- ✅ Извлечение логики в computed properties
- ✅ Разбиение UI на мелкие компоненты
- ✅ Guard для читаемости валидации
- ✅ Семантичные названия переменных

---

## ❌ Антипаттерны (что ЗАПРЕЩЕНО)

### 1. ❌ Использование `print()` без смысла в продакшене
```swift
// ПЛОХО
func sendMessage() {
    print("sending")
    print("message sent")
}

// ХОРОШО
func sendMessage() {
    print("📤 Отправка сообщения на Claude API...")
    // ... код ...
    print("✅ Сообщение успешно отправлено")
}
```

**Правило:** Используйте логирование с emoji и смысловой информацией, либо используйте Logger

---

### 2. ❌ Хардкод API ключей и секретов
```swift
// ПЛОХО
let apiKey = "sk-ant-api03-abc123..."

// ХОРОШО
let apiKey = settings.apiKey
```

**Правило:** Все секреты через Settings или Keychain

---

### 3. ❌ Force unwrap без проверки
```swift
// ПЛОХО
let url = URL(string: someString)!
let data = try! JSONDecoder().decode(Model.self, from: jsonData)

// ХОРОШО
guard let url = URL(string: someString) else {
    completion(.failure(URLError(.badURL)))
    return
}

do {
    let data = try JSONDecoder().decode(Model.self, from: jsonData)
} catch {
    print("❌ Ошибка декодирования: \(error)")
    completion(.failure(error))
}
```

**Правило:** Всегда обрабатывайте ошибки gracefully

---

### 4. ❌ Использование `Any` вместо конкретных типов
```swift
// ПЛОХО
func getData() -> Any {
    return ["key": "value"]
}

// ХОРОШО
func getData() -> [String: String] {
    return ["key": "value"]
}

// ЕЩЕ ЛУЧШЕ
struct ResponseData: Codable {
    let key: String
}

func getData() -> ResponseData {
    return ResponseData(key: "value")
}
```

**Правило:** Всегда используйте type-safe типы

---

### 5. ❌ Блокирование главного потока
```swift
// ПЛОХО
func loadData() {
    let data = try? Data(contentsOf: url) // блокирует UI
    DispatchQueue.main.async {
        self.data = data
    }
}

// ХОРОШО
func loadData() {
    URLSession.shared.dataTask(with: url) { data, response, error in
        DispatchQueue.main.async {
            self.data = data
        }
    }.resume()
}

// ЕЩЕ ЛУЧШЕ (Swift 6)
func loadData() async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}
```

**Правило:** Используйте async/await или background queues

---

### 6. ❌ Создание UI компонентов в ViewModel
```swift
// ПЛОХО
class ChatViewModel: ObservableObject {
    func createMessageView() -> some View {
        Text("Hello")
    }
}

// ХОРОШО
class ChatViewModel: ObservableObject {
    @Published var messageText: String = "Hello"
}

struct MessageView: View {
    let text: String
    var body: some View {
        Text(text)
    }
}
```

**Правило:** ViewModel отвечает за данные, View за отображение

---

### 7. ❌ Прямое использование UserDefaults вместо Settings
```swift
// ПЛОХО
class SomeService {
    func getAPIKey() -> String {
        return UserDefaults.standard.string(forKey: "APIKey") ?? ""
    }
}

// ХОРОШО
class SomeService {
    private let settings: Settings

    init(settings: Settings) {
        self.settings = settings
    }

    func getAPIKey() -> String {
        return settings.apiKey
    }
}
```

**Правило:** Централизованный Settings класс для всех настроек

---

### 8. ❌ Весь UI экрана в одном файле
```swift
// ПЛОХО — 200 строк в одном файле
// ChatView.swift
struct ChatView: View {
    var body: some View {
        VStack {
            HStack {
                // 40 строк шапки...
            }
            ScrollView {
                // 60 строк списка сообщений...
            }
            HStack {
                // 50 строк поля ввода...
            }
        }
    }
}

// ХОРОШО — каждый блок в своём файле
// ChatView.swift — только компоновка
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(viewModel: viewModel)       // ChatHeaderView.swift
            MessageListView(messages: viewModel.messages)  // MessageListView.swift
            ChatInputBarView(viewModel: viewModel)     // ChatInputBarView.swift
        }
    }
}
```

**Правило:** `body` главного экрана — только встраивание дочерних компонентов. Каждый крупный UI-блок — отдельный файл. Максимум 2-3 уровня вложенности в одном файле.

---

## 🗂️ Шаблон файла

### Для Service:
```swift
//
//  MyNewService.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on DD.MM.YYYY.
//

import Foundation

class MyNewService {
    // MARK: - Properties

    private let settings: Settings

    // MARK: - Initialization

    init(settings: Settings) {
        self.settings = settings
    }

    // MARK: - Public Methods

    func performAction() async throws -> Result {
        // Implementation
    }

    // MARK: - Private Methods

    private func helperMethod() {
        // Implementation
    }
}

// MARK: - Supporting Types

struct Result: Codable {
    let data: String
}
```

---

### Для Model:
```swift
//
//  MyModel.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on DD.MM.YYYY.
//

import Foundation

struct MyModel: Identifiable, Codable, Equatable {
    // MARK: - Properties

    let id: UUID
    let title: String
    var metadata: Metadata?

    // MARK: - Nested Types

    struct Metadata: Codable {
        let createdAt: Date
    }

    // MARK: - Initializers

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.metadata = nil
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        !title.isEmpty
    }
}
```

---

### Для View (главный экран — только компоновка):
```swift
//
//  MyFeatureView.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on DD.MM.YYYY.
//

import SwiftUI

// Главный экран: ТОЛЬКО компоновка дочерних компонентов
struct MyFeatureView: View {
    // MARK: - Dependencies

    @ObservedObject var viewModel: MyFeatureViewModel

    // MARK: - State

    @State private var isShowingDetail = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            MyFeatureHeaderView(title: viewModel.title)         // MyFeatureHeaderView.swift
            MyFeatureContentView(items: viewModel.items)        // MyFeatureContentView.swift
            MyFeatureFooterView(onAction: viewModel.doAction)   // MyFeatureFooterView.swift
        }
    }
}

// MARK: - Preview

#Preview {
    MyFeatureView(viewModel: MyFeatureViewModel())
}
```

### Для View (дочерний компонент):
```swift
//
//  MyFeatureHeaderView.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on DD.MM.YYYY.
//

import SwiftUI

struct MyFeatureHeaderView: View {
    // MARK: - Properties

    let title: String

    // MARK: - Body

    var body: some View {
        HStack {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    MyFeatureHeaderView(title: "Preview Title")
}
```

---

## 🔧 Дополнительные правила

### Импорты
```swift
// Порядок импортов:
import Foundation        // Стандартные
import SwiftUI
import Combine

import MCP              // Внешние библиотеки
import SQLite3

import AppKit           // Системные фреймворки
import Speech
```

---

### Комментарии
```swift
// MARK: - используется для разделения секций
// TODO: - для будущих задач
// FIXME: - для известных проблем
// NOTE: - для важных замечаний

// Inline комментарии для сложной логики
let tokens = text.count / 4  // Примерно 4 символа = 1 токен
```

---

### Error Handling
```swift
// Предпочитайте Result типы для completion handlers
func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
    // ...
}

// Используйте async throws для новых методов
func fetchData() async throws -> Data {
    // ...
}

// Создавайте кастомные ошибки
enum ServiceError: Error {
    case invalidURL
    case networkError(String)
    case decodingFailed
}
```

---

### Emoji для логирования
```swift
// Используйте эмодзи для визуального разделения логов:
print("🚀 Запуск сервиса...")
print("✅ Успешно выполнено")
print("❌ Ошибка: \(error)")
print("📤 Отправка данных...")
print("📥 Получение данных...")
print("⏰ Таймаут")
print("🔒 Закрытие соединения")
print("📁 Файл сохранен")
print("🔍 Поиск...")
print("💾 Сохранение в базу...")
```

---

## 🎯 Чек-лист перед коммитом

- [ ] Код компилируется без warnings
- [ ] Использованы правильные naming conventions
- [ ] Добавлены MARK: комментарии
- [ ] Нет force unwrap без необходимости
- [ ] Нет хардкода API ключей
- [ ] Async операции не блокируют главный поток
- [ ] Views разбиты на компоненты
- [ ] Модели имеют Codable + Identifiable
- [ ] Сервисы используют DI
- [ ] Есть error handling

---

## 📚 Примеры использования

### Создание нового сервиса
```swift
// 1. Создайте файл в Services/
// 2. Используйте шаблон Service
// 3. Добавьте в ChatViewModel как dependency:

class ChatViewModel: ObservableObject {
    private let myNewService: MyNewService

    init(settings: Settings) {
        self.myNewService = MyNewService(settings: settings)
    }
}
```

### Создание новой модели
```swift
// 1. Создайте файл в Models/
// 2. Используйте Identifiable + Codable
// 3. Добавьте convenience initializer
```

### Создание нового View
```swift
// 1. Создайте файл в Views/
// 2. Получите ViewModel через @ObservedObject
// 3. Разбейте на computed properties
// 4. Добавьте #Preview
```

---

## 🧪 Тестирование

При создании нового функционала, убедитесь:
- Код компилируется
- Нет warnings
- Работает в macOS 15.5+
- UI корректно отображается
- Нет утечек памяти
- Асинхронные операции завершаются

---

## 📖 Дополнительные ресурсы

- **Swift Style Guide:** https://google.github.io/swift/
- **SwiftUI Best Practices:** https://www.swiftbysundell.com
- **MVVM Pattern:** Используется повсеместно в проекте

---

**Версия:** 1.0
**Последнее обновление:** 18.04.2026
**Автор:** Sergey Markov
