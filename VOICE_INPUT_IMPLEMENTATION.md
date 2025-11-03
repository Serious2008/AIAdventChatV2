# Голосовой ввод - Реализация

## ✅ Что реализовано

Минимальная версия голосового ввода с распознаванием речи и отправкой в Claude.

### Архитектура:
```
[Микрофон] → [Apple Speech Recognition] → [Text] → [Claude LLM] → [Text Response]
```

---

## 📁 Созданные/Измененные файлы

### 1. **SpeechRecognitionService.swift** (NEW - 268 строк)

Сервис для распознавания речи с использованием Apple Speech Framework.

**Основные компоненты:**
```swift
class SpeechRecognitionService: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recognizedText: String = ""
    @Published var error: String?
    @Published var isAuthorized: Bool = false

    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
}
```

**Ключевые методы:**

#### `requestAuthorization()` - запрос разрешений
```swift
func requestAuthorization() async -> Bool {
    // Request Speech Recognition
    let speechAuth = await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status == .authorized)
        }
    }

    // On macOS, microphone permission handled automatically
    return speechAuth
}
```

#### `startRecording()` - начало записи
```swift
func startRecording() throws {
    // Create recognition request
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    recognitionRequest?.shouldReportPartialResults = true

    // Get audio input
    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    // Install audio tap
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
        self.recognitionRequest?.append(buffer)
    }

    // Start audio engine
    audioEngine.prepare()
    try audioEngine.start()

    // Start recognition task
    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { result, error in
        if let result = result {
            self.recognizedText = result.bestTranscription.formattedString
        }
    }
}
```

#### `stopRecording()` - остановка записи
```swift
func stopRecording() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
}
```

**Особенности реализации:**
- ✅ Поддержка русского языка (`ru-RU` по умолчанию)
- ✅ Live partial results (промежуточное распознавание)
- ✅ Кроссплатформенность (macOS + iOS с условной компиляцией)
- ✅ Автоматическая обработка ошибок

---

### 2. **ChatViewModel.swift** (MODIFIED)

Добавлена интеграция голосового ввода.

**Новые свойства:**
```swift
// Voice Input
@Published var speechRecognitionService: SpeechRecognitionService
@Published var isListening: Bool = false
@Published var voiceInputText: String = ""
```

**Новые методы:**

#### `startVoiceInput()` - начало голосового ввода
```swift
func startVoiceInput() async {
    // Request authorization
    let authorized = await speechRecognitionService.requestAuthorization()
    guard authorized else {
        self.errorMessage = "Нет разрешения"
        return
    }

    // Start recording
    try speechRecognitionService.startRecording()
    self.isListening = true
}
```

#### `stopVoiceInputAndSend()` - остановка и отправка
```swift
func stopVoiceInputAndSend() {
    speechRecognitionService.stopRecording()

    // Wait for final recognition
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        let recognizedText = self.speechRecognitionService.recognizedText
        self.currentMessage = recognizedText
        self.isListening = false

        if !recognizedText.isEmpty {
            self.sendMessage()
        }
    }
}
```

#### `toggleVoiceInput()` - переключение (start/stop)
```swift
func toggleVoiceInput() {
    if isListening {
        stopVoiceInputAndSend()
    } else {
        Task {
            await startVoiceInput()
        }
    }
}
```

#### `cancelVoiceInput()` - отмена без отправки
```swift
func cancelVoiceInput() {
    speechRecognitionService.cancelRecording()
    isListening = false
    voiceInputText = ""
}
```

---

### 3. **ChatView.swift** (MODIFIED)

Добавлен UI для голосового ввода.

**Кнопка микрофона:**
```swift
// Voice Input Button
Button(action: {
    viewModel.toggleVoiceInput()
}) {
    Image(systemName: viewModel.isListening ? "stop.circle.fill" : "mic.circle.fill")
        .font(.title)
        .foregroundColor(viewModel.isListening ? .red : .blue)
}
.buttonStyle(.plain)
.help(viewModel.isListening ? "Остановить запись и отправить" : "Голосовой ввод")
```

**Индикатор записи:**
```swift
// Voice input indicator
if viewModel.isListening {
    HStack(spacing: 8) {
        Image(systemName: "waveform")
            .foregroundColor(.red)

        Text("Слушаю... (нажмите снова чтобы отправить)")
            .font(.caption)
            .foregroundColor(.red)

        if !viewModel.speechRecognitionService.recognizedText.isEmpty {
            Divider()
            Text("Распознано: \"\(viewModel.speechRecognitionService.recognizedText)\"")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color.red.opacity(0.1))
}
```

**Расположение:**
```
[Pipeline] [TextField] [🎤 Mic] [Send]
```

Во время записи:
```
[Pipeline] [TextField] [⏹ Stop] [Send]
↓
📢 Слушаю... | Распознано: "посчитай два плюс два"
```

---

### 4. **Info.plist** (MODIFIED)

Добавлены разрешения для микрофона и распознавания речи.

```xml
<key>NSMicrophoneUsageDescription</key>
<string>AIAdventChat нужен доступ к микрофону для распознавания голосовых команд и преобразования речи в текст</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>AIAdventChat использует распознавание речи для преобразования ваших голосовых команд в текст, который затем отправляется в AI модель</string>
```

---

## 🎨 UI/UX описание

### Обычное состояние:
- Кнопка микрофона 🎤 синего цвета
- Hover: "Голосовой ввод"

### Во время записи:
- Кнопка меняется на ⏹ красного цвета
- Hover: "Остановить запись и отправить"
- Под полем ввода появляется красная полоса с индикатором
- Показывается текст "Слушаю..."
- Live отображение распознанного текста

### После остановки:
- Пауза 0.5s для финального распознавания
- Текст автоматически вставляется в поле ввода
- Отправляется в Claude через `sendMessage()`
- Ответ отображается как обычное сообщение

---

## 🧪 Как тестировать

### Шаг 1: Запустите приложение
```bash
xcodebuild -scheme AIAdventChatV2 -configuration Debug
# или через Xcode: Cmd+R
```

### Шаг 2: Первый запуск - разрешения
1. Нажмите кнопку микрофона 🎤
2. Система запросит разрешение на:
   - Распознавание речи
   - Доступ к микрофону
3. Разрешите оба

### Шаг 3: Тестовые команды

#### Тест 1: Математика
**Говорите:** "Посчитай два плюс два"

**Ожидается:**
- Распознано: "посчитай два плюс два" или "Посчитай 2 + 2"
- Отправлено в Claude
- Ответ: "2 + 2 = 4"

---

#### Тест 2: Определение
**Говорите:** "Дай определение машинного обучения"

**Ожидается:**
- Распознано: "дай определение машинного обучения"
- Ответ с определением ML

---

#### Тест 3: Анекдот
**Говорите:** "Скажи анекдот"

**Ожидается:**
- Распознано: "скажи анекдот"
- Claude рассказывает анекдот

---

#### Тест 4: С RAG (если включен)
**Говорите:** "Как работает векторный поиск"

**Ожидается:**
- Распознано текст
- RAG ищет в документах
- Ответ с цитатами [Источник 1], [Источник 2]
- Отображаются источники

---

### Шаг 4: Проверка индикатора

**Во время записи должно быть видно:**
- ✅ Красная кнопка ⏹
- ✅ Красная полоса "Слушаю..."
- ✅ Live текст: "Распознано: ..."
- ✅ Waveform иконка 📊

**После остановки:**
- ✅ Текст в поле ввода
- ✅ Сообщение отправлено
- ✅ Ответ получен

---

## 📊 Технические детали

### Язык распознавания:
По умолчанию: **русский** (`ru-RU`)

Изменить можно в инициализации:
```swift
self.speechRecognitionService = SpeechRecognitionService(
    locale: Locale(identifier: "en-US") // для английского
)
```

### Partial Results:
Включено (`shouldReportPartialResults = true`)
- Видно промежуточное распознавание
- Обновляется в реальном времени

### Timeout:
Нет автоматического timeout
- Пользователь сам останавливает запись
- Click to start, click to stop

### Обработка ошибок:
```swift
if error != nil {
    self.errorMessage = "Ошибка записи: \(error.localizedDescription)"
}
```

### Кроссплатформенность:
```swift
#if os(iOS)
// iOS-specific code (AVAudioSession)
#else
// macOS (no AVAudioSession needed)
#endif
```

---

## 🎯 Примеры использования

### Пример 1: Быстрый вопрос
```
1. [Нажать 🎤]
2. "Посчитай пять умножить на семь"
3. [Нажать ⏹]
4. → Распознано: "посчитай пять умножить на семь"
5. → Отправлено в Claude
6. ← Ответ: "5 × 7 = 35"
```

### Пример 2: С RAG
```
1. [Включить RAG toggle]
2. [Нажать 🎤]
3. "Где сохраняются сообщения чата"
4. [Нажать ⏹]
5. → Распознано текст
6. → RAG ищет в коде
7. ← Ответ с цитатами: "Сообщения сохраняются в MessageDatabase [Источник 1]..."
8. ← Источники: MessageDatabase.swift
```

### Пример 3: Длинный запрос
```
1. [Нажать 🎤]
2. Говорить: "Объясни подробно как работает векторный поиск,
   какие алгоритмы используются и как вычисляется similarity"
3. Видно live: "Объясни подробно как работает..."
4. [Нажать ⏹]
5. → Весь текст распознан
6. → Отправлен в Claude
7. ← Подробный ответ
```

---

## 🐛 Возможные проблемы и решения

### Проблема 1: "Нет разрешения"
**Причина:** Не разрешён доступ к микрофону или Speech Recognition

**Решение:**
1. Откройте System Settings → Privacy & Security
2. Найдите Microphone → разрешите AIAdventChat
3. Найдите Speech Recognition → разрешите
4. Перезапустите приложение

---

### Проблема 2: Не распознаёт речь
**Причина:** Плохое качество микрофона или фоновый шум

**Решение:**
- Говорите чётче и громче
- Уменьшите фоновый шум
- Проверьте микрофон в System Settings

---

### Проблема 3: Распознаёт неправильно
**Причина:** Акцент, технические термины

**Решение:**
- Говорите медленнее
- Повторите попытку
- Для технических терминов лучше печатать вручную

---

### Проблема 4: Зависает на "Слушаю..."
**Причина:** Recognizer не получает финальный результат

**Решение:**
- Нажмите кнопку ⏹ ещё раз
- Если не помогает - перезапустите приложение

---

## 🚀 Будущие улучшения (не реализовано)

### 1. Push-to-Talk режим
```swift
// Hold button - record, release - send
.onLongPressGesture(minimumDuration: 0.1) { }
```

### 2. Auto-stop при тишине
```swift
// Detect silence > 2s → auto stop
private func detectSilence() { }
```

### 3. Waveform visualization
```swift
// Visual audio levels
@Published var audioLevel: Float = 0.0
```

### 4. Выбор языка в Settings
```swift
@AppStorage("speechLanguage") var speechLanguage = "ru-RU"
```

### 5. Whisper API опция
```swift
// For higher accuracy
@AppStorage("useWhisperAPI") var useWhisperAPI = false
```

### 6. Voice Activity Detection
```swift
// Smart detection when user stops speaking
```

### 7. История голосовых команд
```swift
struct VoiceCommand {
    let audio: Data
    let recognized: String
    let response: String
}
```

---

## 📈 Результат

### ✅ Реализовано:
- Распознавание речи (Apple Speech Framework)
- Кнопка микрофона в UI
- Live отображение распознанного текста
- Автоматическая отправка в Claude
- Индикатор записи
- Обработка ошибок
- Кроссплатформенность (macOS + iOS)
- Поддержка русского языка
- Click-to-start, click-to-stop

### 📊 Статистика:
- **Файлов создано:** 1 (SpeechRecognitionService.swift)
- **Файлов изменено:** 3 (ChatViewModel, ChatView, Info.plist)
- **Строк кода:** ~370
- **Время реализации:** ~2-3 часа
- **Сложность:** Минимальная версия ✅

### 🎯 Качество:
- **Build:** ✅ SUCCESS
- **Warnings:** Только deprecation warnings (не критично)
- **Errors:** Нет
- **Готовность:** Готово к тестированию

---

## 🎓 Как работает (техническое описание)

### Схема потока данных:
```
User speaks
    ↓
Microphone captures audio
    ↓
AVAudioEngine → audio buffer
    ↓
SFSpeechAudioBufferRecognitionRequest
    ↓
SFSpeechRecognizer (Apple servers)
    ↓
Transcription result (partial + final)
    ↓
recognizedText updates (live)
    ↓
User stops recording
    ↓
Wait 0.5s for final result
    ↓
Set as currentMessage
    ↓
sendMessage() → Claude API
    ↓
Response displayed
```

### Компоненты Apple Speech Framework:
1. **SFSpeechRecognizer** - распознаватель (ru-RU)
2. **AVAudioEngine** - аудио движок (микрофон)
3. **SFSpeechAudioBufferRecognitionRequest** - запрос с аудио
4. **SFSpeechRecognitionTask** - задача распознавания

### Threading:
- Audio capture: Background thread (AVAudioEngine)
- Recognition: Background thread (Speech Framework)
- UI updates: Main thread (@MainActor)

---

## ✅ Готово к использованию!

Запустите приложение и протестируйте голосовой ввод с командами:
- "Посчитай два плюс два"
- "Дай определение машинного обучения"
- "Скажи анекдот"
- "Как работает векторный поиск" (с RAG)

**Результат:** Голосовой агент с текстовым выводом! 🎤→🤖
