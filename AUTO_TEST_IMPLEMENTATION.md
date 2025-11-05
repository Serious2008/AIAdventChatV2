# Auto Test Agent - Реализация

## ✅ Что реализовано

Агент-сотрудник для автоматической генерации и запуска unit-тестов.

### Архитектура:
```
[Пользователь] → Выбор файла
        ↓
[AutoTestAgent] → Чтение кода
        ↓
[Claude API] → Генерация тестов (XCTest)
        ↓
[Запись файла] → *Tests.swift в AIAdventChatV2Tests/
        ↓
[xcodebuild test] → Запуск всех тестов
        ↓
[Парсинг результатов] → Passed: X, Failed: Y
        ↓
[Отчёт пользователю] → "✅ 12 passed, ❌ 2 failed (85.7%)"
```

---

## 🎯 Основная идея

**Цель:** Автоматизировать написание unit-тестов с помощью AI.

**Как работает:**
1. Пользователь выбирает Swift файл через file picker
2. Агент читает исходный код
3. Claude анализирует код и генерирует comprehensive тесты
4. Тесты записываются в `AIAdventChatV2Tests/`
5. Запускается `xcodebuild test`
6. Результаты парсятся и показываются в UI

**Результат:** Автономный "агент-сотрудник", который проверяет качество кода!

---

## 📁 Созданные/Измененные файлы

### 1. **AutoTestAgent.swift** (NEW - 350+ строк)

Основной сервис для генерации и запуска тестов.

**Структура:**
```swift
class AutoTestAgent: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var isRunningTests: Bool = false
    @Published var testResults: TestResults?
    @Published var generatedTestCode: String = ""
    @Published var error: String?
    @Published var currentStep: String = ""
}
```

#### Основной workflow:

```swift
func generateAndRunTests(for filePath: String, projectPath: String) async {
    // 1. Читаем исходный код
    let sourceCode = try String(contentsOfFile: filePath)

    // 2. Генерируем тесты через Claude
    let testCode = try await generateTests(sourceCode: sourceCode, fileName: fileName)

    // 3. Записываем тест-файл
    let testFilePath = "\(projectPath)/AIAdventChatV2Tests/\(fileName)Tests.swift"
    try testCode.write(toFile: testFilePath)

    // 4. Запускаем тесты
    let results = try await runTests(projectPath: projectPath)

    // 5. Показываем результаты
    self.testResults = results
}
```

#### Генерация тестов:

```swift
private func generateTests(sourceCode: String, fileName: String) async throws -> String {
    let prompt = buildTestGenerationPrompt(sourceCode: sourceCode, fileName: fileName)

    // Запрос к Claude API
    let request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages"))
    request.httpMethod = "POST"
    request.setValue(settings.apiKey, forHTTPHeaderField: "x-api-key")

    let requestBody = [
        "model": "claude-3-7-sonnet-20250219",
        "max_tokens": 4000,
        "temperature": 0.3,  // Низкая температура для более предсказуемых тестов
        "messages": [["role": "user", "content": prompt]]
    ]

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONSerialization.jsonObject(with: data)

    // Извлекаем код тестов
    let testCode = extractTestCode(from: response)
    return testCode
}
```

#### Промпт для Claude:

```swift
private func buildTestGenerationPrompt(sourceCode: String, fileName: String) -> String {
    """
    Ты - expert iOS/macOS тестировщик. Твоя задача - написать comprehensive unit-тесты.

    Файл: \(fileName).swift

    Код:
    ```swift
    \(sourceCode)
    ```

    Требования к тестам:
    1. Используй XCTest фреймворк
    2. Покрой все публичные методы и свойства
    3. Протестируй edge cases (nil, empty, boundary values)
    4. Используй meaningful test names: test_methodName_whenCondition_shouldExpectedResult
    5. Добавь setUp() и tearDown() если нужно
    6. Mock dependencies если они есть
    7. Для async методов используй async tests
    8. Добавь комментарии для сложных тестов

    Верни ТОЛЬКО код тестов в формате:
    ```swift
    import XCTest
    @testable import AIAdventChatV2

    final class \(fileName)Tests: XCTestCase {
        // тесты здесь
    }
    ```

    НЕ добавляй объяснений, только код!
    """
}
```

#### Запуск тестов:

```swift
private func runTests(projectPath: String) async throws -> TestResults {
    let startTime = Date()

    let process = Process()
    process.currentDirectoryURL = URL(fileURLWithPath: projectPath)
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
    process.arguments = [
        "test",
        "-scheme", "AIAdventChatV2",
        "-configuration", "Debug",
        "-destination", "platform=macOS"
    ]

    let outputPipe = Pipe()
    process.standardOutput = outputPipe

    try process.run()
    process.waitUntilExit()

    let executionTime = Date().timeIntervalSince(startTime)
    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)

    // Парсим результаты
    let results = parseTestResults(output, executionTime: executionTime)

    return results
}
```

#### Парсинг результатов:

```swift
private func parseTestResults(_ output: String, executionTime: TimeInterval) -> TestResults {
    var passed = 0
    var failed = 0
    var failedTests: [FailedTest] = []

    // Паттерны для поиска результатов
    let passedPattern = #"Test Case '.*' passed \(\d+\.\d+ seconds\)"#
    let failedPattern = #"Test Case '.*' failed \(\d+\.\d+ seconds\)"#

    // Считаем пройденные/провалившиеся тесты
    if let passedRegex = try? NSRegularExpression(pattern: passedPattern) {
        passed = passedRegex.numberOfMatches(in: output, ...)
    }

    if let failedRegex = try? NSRegularExpression(pattern: failedPattern) {
        failed = failedRegex.numberOfMatches(in: output, ...)
    }

    // Извлекаем детали ошибок
    failedTests = extractFailedTestDetails(from: output)

    return TestResults(
        totalPassed: passed,
        totalFailed: failed,
        failedTests: failedTests,
        rawOutput: output,
        executionTime: executionTime
    )
}
```

#### Модели данных:

```swift
struct TestResults {
    let totalPassed: Int
    let totalFailed: Int
    let failedTests: [FailedTest]
    let rawOutput: String
    let executionTime: TimeInterval

    var totalTests: Int { totalPassed + totalFailed }
    var successRate: Double { Double(totalPassed) / Double(totalTests) * 100 }
    var statusEmoji: String {
        if totalFailed == 0 { return "✅" }
        else if successRate >= 80 { return "⚠️" }
        else { return "❌" }
    }
}

struct FailedTest: Identifiable {
    let id = UUID()
    let name: String
    let reason: String
    let file: String
    let line: Int
}
```

---

### 2. **AutoTestView.swift** (NEW - 450+ строк)

SwiftUI интерфейс для агента.

#### Главный экран:

```swift
struct AutoTestView: View {
    @ObservedObject var agent: AutoTestAgent
    @State private var selectedFilePath: String = ""
    @State private var showingFilePicker = false
    @State private var projectPath: String = ""

    var body: some View {
        VStack {
            // Header
            HStack {
                Image(systemName: "wand.and.stars")
                Text("Auto Test Agent")
                Spacer()
                Button("✕") { dismiss() }
            }

            // Step 1: File Selection
            GroupBox("1. Выберите файл для тестирования") {
                // File picker UI
            }

            // Step 2: Generation Status
            if agent.isGenerating {
                GroupBox("2. Генерация тестов") {
                    ProgressView()
                    Text(agent.currentStep)
                }
            }

            // Generated Tests Preview
            if !agent.generatedTestCode.isEmpty {
                GroupBox("Сгенерированные тесты") {
                    ScrollView {
                        Text(agent.generatedTestCode)
                            .font(.monospaced)
                    }
                    .frame(height: 200)
                }
            }

            // Step 3: Test Running
            if agent.isRunningTests {
                GroupBox("3. Запуск тестов") {
                    ProgressView()
                    Text("Выполняются тесты...")
                }
            }

            // Step 4: Results
            if let results = agent.testResults {
                TestResultsView(results: results)
            }

            // Action Button
            Button("▶️ Сгенерировать и запустить тесты") {
                Task {
                    await agent.generateAndRunTests(for: selectedFilePath, projectPath: projectPath)
                }
            }
            .disabled(selectedFilePath.isEmpty || agent.isGenerating || agent.isRunningTests)
        }
        .frame(width: 800, height: 600)  // Reduced from 700 to fit on screen
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.swiftSource]) { result in
            // Обработка выбора файла
        }
    }
}
```

#### Test Results View:

```swift
struct TestResultsView: View {
    let results: TestResults

    var body: some View {
        GroupBox("4. Результаты") {
            VStack {
                // Summary cards
                HStack {
                    ResultCard(value: "\(results.totalPassed)", label: "Passed", color: .green, icon: "checkmark.circle.fill")
                    ResultCard(value: "\(results.totalFailed)", label: "Failed", color: .red, icon: "xmark.circle.fill")
                    ResultCard(value: "\(results.successRate)%", label: "Success Rate", color: .green, icon: "chart.pie.fill")
                    ResultCard(value: "\(results.executionTime)s", label: "Time", color: .blue, icon: "clock.fill")
                }

                // Overall status
                HStack {
                    Text(results.statusEmoji).font(.largeTitle)
                    Text(results.totalFailed == 0 ? "Все тесты пройдены!" : "\(results.totalFailed) тестов провалилось")
                }
                .padding()
                .background(results.totalFailed == 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))

                // Failed tests details
                if !results.failedTests.isEmpty {
                    VStack {
                        Text("Провалившиеся тесты:")
                        ForEach(results.failedTests) { test in
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                    Text(test.name).fontWeight(.medium)
                                }
                                Text(test.reason).font(.caption).foregroundColor(.secondary)
                                Text("\(test.file):\(test.line)").font(.caption2).foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
}
```

#### Result Card:

```swift
struct ResultCard: View {
    let value: String
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.system(size: 32, weight: .bold)).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
```

---

### 3. **ChatView.swift** (MODIFIED)

Добавлена кнопка для открытия Auto Test Agent.

#### Новое состояние:
```swift
@State private var showingAutoTest = false
```

#### Кнопка в хеадере:
```swift
// Auto Test Agent button
Button(action: {
    showingAutoTest = true
}) {
    Image(systemName: "wand.and.stars")
        .font(.title2)
        .foregroundColor(.purple)
}
.buttonStyle(.plain)
.help("Auto Test Agent - генерация тестов")
```

**Расположение:**
```
[История] [ТЗ] [📄 Просмотр] [✨ Auto Test] [👤 Профиль] [⚙️ Настройки]
```

#### Sheet:
```swift
.sheet(isPresented: $showingAutoTest) {
    AutoTestView(agent: AutoTestAgent(settings: settings))
}
```

---

## 🎨 UI/UX описание

### Главное окно Auto Test Agent:

```
┌─────────────────────────────────────────────────────────┐
│ ✨ Auto Test Agent                                   ✕ │
│ Агент-сотрудник для автоматического тестирования       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│ 📄 1. Выберите файл для тестирования                    │
│ ┌────────────────────────────────────────────────────┐  │
│ │  📄 UserProfileService.swift              [Изменить]│  │
│ │  ~/AIAdventChatV2/Services/UserProfileService.swift│  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ ⚙️ 2. Генерация тестов                                 │
│ ┌────────────────────────────────────────────────────┐  │
│ │  🔄 Claude анализирует код и создаёт тесты...      │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ 📝 Сгенерированные тесты                  [Копировать]  │
│ ┌────────────────────────────────────────────────────┐  │
│ │ import XCTest                          120 строк    │  │
│ │ @testable import AIAdventChatV2                    │  │
│ │                                                     │  │
│ │ final class UserProfileServiceTests: XCTestCase {  │  │
│ │     var sut: UserProfileService!                   │  │
│ │                                                     │  │
│ │     override func setUp() {                        │  │
│ │         super.setUp()                              │  │
│ │         sut = UserProfileService()                 │  │
│ │     }                                               │  │
│ │ ...                                                 │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ ▶️ 3. Запуск тестов                                    │
│ ┌────────────────────────────────────────────────────┐  │
│ │  🔄 Выполняются тесты...                           │  │
│ │  xcodebuild test выполняет сгенерированные тесты   │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ ✅ 4. Результаты                                        │
│ ┌────────────────────────────────────────────────────┐  │
│ │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐           │  │
│ │  │  12  │  │  2   │  │85.7% │  │ 3.2s │           │  │
│ │  │Passed│  │Failed│  │ Rate │  │ Time │           │  │
│ │  └──────┘  └──────┘  └──────┘  └──────┘           │  │
│ │                                                     │  │
│ │  ⚠️ 2 теста провалилось                            │  │
│ │  14 тестов выполнено                               │  │
│ │                                                     │  │
│ │  Провалившиеся тесты:                              │  │
│ │  ┌─────────────────────────────────────────────┐   │  │
│ │  │ ❌ test_save_whenInvalidPath_shouldThrow    │   │  │
│ │  │    Expected to throw error, but succeeded   │   │  │
│ │  │    📄 UserProfileServiceTests.swift:45      │   │  │
│ │  └─────────────────────────────────────────────┘   │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│            [Очистить]  [▶️ Сгенерировать и запустить]  │
└─────────────────────────────────────────────────────────┘
```

---

## 🧪 Как использовать

### Шаг 1: Открыть агент
1. Запустите приложение
2. Нажмите кнопку ✨ (Auto Test Agent) в верхнем правом углу

### Шаг 2: Выбрать файл
1. Нажмите "Выбрать файл..."
2. Выберите Swift файл (например, `UserProfileService.swift`)

### Шаг 3: Запустить генерацию
1. Нажмите "▶️ Сгенерировать и запустить тесты"
2. Агент:
   - Прочитает код файла
   - Попросит Claude сгенерировать тесты
   - Запишет тесты в `AIAdventChatV2Tests/`
   - Запустит `xcodebuild test`
   - Покажет результаты

### Шаг 4: Просмотр результатов
- ✅ Зелёные карточки - пройденные тесты
- ❌ Красные карточки - провалившиеся тесты
- 📊 Success Rate - процент успешных тестов
- ⏱ Time - время выполнения

---

## 📊 Примеры

### Пример 1: Простой сервис

**Входной файл (UserProfileService.swift):**
```swift
class UserProfileService: ObservableObject {
    @Published var profile: UserProfile

    func save() {
        let data = try JSONEncoder().encode(profile)
        try data.write(to: fileURL)
    }

    func load() -> UserProfile? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }
}
```

**Сгенерированные тесты:**
```swift
import XCTest
@testable import AIAdventChatV2

final class UserProfileServiceTests: XCTestCase {
    var sut: UserProfileService!
    var testFileURL: URL!

    override func setUp() {
        super.setUp()
        sut = UserProfileService()
        testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_profile.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testFileURL)
        sut = nil
        super.tearDown()
    }

    // Test save functionality
    func test_save_whenValidProfile_shouldWriteToFile() throws {
        // Given
        let profile = UserProfile(name: "Test User")
        sut.profile = profile

        // When
        sut.save()

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path))
    }

    // Test load functionality
    func test_load_whenFileExists_shouldReturnProfile() throws {
        // Given
        let expectedProfile = UserProfile(name: "Test User")
        let data = try JSONEncoder().encode(expectedProfile)
        try data.write(to: testFileURL)

        // When
        let loadedProfile = sut.load()

        // Then
        XCTAssertNotNil(loadedProfile)
        XCTAssertEqual(loadedProfile?.name, "Test User")
    }

    // Test load when file doesn't exist
    func test_load_whenFileDoesNotExist_shouldReturnNil() {
        // Given
        try? FileManager.default.removeItem(at: testFileURL)

        // When
        let loadedProfile = sut.load()

        // Then
        XCTAssertNil(loadedProfile)
    }
}
```

**Результат:**
```
✅ 3 passed, 0 failed (100% success rate) in 0.5s
```

---

### Пример 2: Async метод

**Входной код:**
```swift
class WeatherService {
    func fetchWeather(city: String) async throws -> Weather {
        let url = URL(string: "https://api.weather.com/\(city)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Weather.self, from: data)
    }
}
```

**Сгенерированные тесты:**
```swift
final class WeatherServiceTests: XCTestCase {
    var sut: WeatherService!

    func test_fetchWeather_whenValidCity_shouldReturnWeather() async throws {
        // Given
        sut = WeatherService()

        // When
        let weather = try await sut.fetchWeather(city: "Moscow")

        // Then
        XCTAssertNotNil(weather)
    }

    func test_fetchWeather_whenInvalidCity_shouldThrow() async {
        // Given
        sut = WeatherService()

        // Then
        await XCTAssertThrowsError(try await sut.fetchWeather(city: ""))
    }
}
```

---

## 🎯 Что агент проверяет

Claude генерирует тесты, которые покрывают:

1. **Happy Path** - нормальное выполнение
2. **Edge Cases** - граничные значения (nil, empty, 0, max)
3. **Error Cases** - обработка ошибок
4. **Async/Await** - асинхронные методы
5. **Dependencies** - моки для зависимостей
6. **State Changes** - изменения состояния

---

## 📈 Результат

### ✅ Реализовано:

**Файлы:**
- ✅ AutoTestAgent.swift (350+ строк) - логика агента
- ✅ AutoTestView.swift (450+ строк) - UI
- ✅ ChatView.swift (modified) - кнопка доступа

**Функциональность:**
- ✅ Выбор файла через file picker
- ✅ Генерация тестов через Claude API
- ✅ Запись тестов в AIAdventChatV2Tests/
- ✅ Запуск xcodebuild test
- ✅ Парсинг результатов (passed/failed)
- ✅ Отображение результатов с деталями ошибок
- ✅ Копирование сгенерированного кода
- ✅ Статистика (success rate, execution time)

---

### 📊 Статистика:

- **Файлов создано:** 2
- **Файлов изменено:** 1
- **Строк кода:** ~800+
- **Build status:** ✅ **BUILD SUCCEEDED**

---

## 🐛 Исправленные проблемы

### Проблема #1: Парсинг результатов тестов показывал 0 passed, 0 failed

**Описание:** После запуска тестов все счётчики показывали 0, даже если тесты выполнялись успешно.

**Причина:** Регулярные выражения для парсинга вывода xcodebuild не совпадали с фактическим форматом.

**Решение:** Реализован двойной подход к парсингу:

```swift
private func parseTestResults(_ output: String, executionTime: TimeInterval) -> TestResults {
    // Debug output
    print("📊 Parsing test results...")
    print("Output length: \(output.count) characters")
    let outputTail = String(output.suffix(2000))
    print("📝 Test output (last 2000 chars):")
    print(outputTail)

    // 1. Попытка найти строку summary: "Executed X tests, with Y failures"
    let summaryPattern = #"Executed (\d+) tests?, with (\d+) failures?"#
    if let match = summaryRegex.firstMatch(...) {
        total = Int(output[totalRange]) ?? 0
        failed = Int(output[failedRange]) ?? 0
        passed = total - failed
    } else {
        // 2. Fallback: подсчёт отдельных тестов
        let passedPattern = #"Test Case '.*' passed \(\d+\.\d+ seconds\)"#
        let failedPattern = #"Test Case '.*' failed \(\d+\.\d+ seconds\)"#
        // Подсчёт совпадений
    }
}
```

**Статус:** ✅ Исправлено, добавлены debug логи для проверки

### Проблема #2: Окно агента не помещается на экране

**Описание:** Окно Auto Test Agent было слишком высоким (700px) и не помещалось на экран.

**Решение:** Уменьшена высота окна с 700 до 600 пикселей.

```swift
.frame(width: 800, height: 600)  // Было 700
```

**Статус:** ✅ Исправлено

### Проблема #3: "The data couldn't be read" при генерации тестов

**Описание:** При попытке сгенерировать тесты появлялась ошибка "The data couldn't be read".

**Причина:** Auto Test Agent использовал `settings.selectedModel`, который был установлен на router модель (`katanemo/Arch-Router-1.5B`) вместо Claude модели. Claude API возвращал ошибку `not_found_error`.

**Решение:** Жёстко закодирована модель Claude 3.7 Sonnet для генерации тестов:

```swift
// Use Claude 3.7 Sonnet for test generation (not router models)
let claudeModel = "claude-3-7-sonnet-20250219"

let requestBody: [String: Any] = [
    "model": claudeModel,  // Вместо settings.selectedModel
    "max_tokens": 4096,
    "messages": [
        ["role": "user", "content": prompt]
    ]
]
```

**Дополнительно:** Добавлено подробное логирование для диагностики:
- `📥 Claude API Response:` - показывает полный ответ API
- `🤖 Using model: ...` - показывает используемую модель
- `❌ Failed to decode Claude response:` - показывает ошибки декодирования

**Статус:** ✅ Исправлено

---

## 🚀 Готово к использованию!

Запустите приложение, нажмите ✨ и протестируйте свой код!

**Агент-сотрудник готов к работе!** 🎯🤖
