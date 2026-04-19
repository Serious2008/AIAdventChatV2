//
//  ChatViewModel.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 01.10.2025.
//

import Foundation
import Combine
import AppKit

enum ConversationMode {
    case normal
    case collectingRequirements
}

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var conversationMode: ConversationMode = .normal
    @Published var generatedDocument: String?
    @Published var loadingMessage: String = "Claude печатает..."
    @Published var summarizationProgress: String?

    // History Compression
    @Published var compressedHistory: CompressedConversationHistory = CompressedConversationHistory()
    @Published var compressionStats: CompressionStats = CompressionStats()
    @Published var isCompressing: Bool = false

    // Long-term Memory Persistence
    @Published var currentConversationId: String = UUID().uuidString
    @Published var conversationTitle: String = "Новый разговор"
    private var isAutoSavingEnabled: Bool = true
    private let dbManager = DatabaseManager.shared
    private let jsonManager = JSONMemoryManager.shared

    // Text Processing Pipeline
    @Published var pipelineResult: PipelineResult?
    @Published var showingPipelineResult: Bool = false
    @Published var isProcessingText: Bool = false

    // Vector Search
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var isIndexing: Bool = false
    @Published var indexingProgress: String = ""
    @Published var indexingStatistics: IndexingStatistics?
    @Published var showingSearchResults: Bool = false

    // Voice Input
    @Published var speechRecognitionService: SpeechRecognitionService
    @Published var isListening: Bool = false
    @Published var voiceInputText: String = ""

    // User Personalization
    @Published var userProfileService: UserProfileService

    internal let settings: Settings
    private var cancellables = Set<AnyCancellable>()
    private let huggingFaceService = HuggingFaceService()
    private let claudeService = ClaudeService()
    private let localModelService = LocalModelService()
    private let ollamaService = OllamaService()
    private let yandexTrackerService = YandexTrackerService()
    private let periodicTaskService = PeriodicTaskService()
    private let simulatorService = SimulatorService()
    private lazy var compressionService: HistoryCompressionService = {
        HistoryCompressionService(claudeService: claudeService, settings: settings)
    }()
    private lazy var textPipeline: TextProcessingPipeline = {
        TextProcessingPipeline(apiService: claudeService, settings: settings)
    }()
    private var _vectorSearchService: VectorSearchService?
    private var vectorSearchService: VectorSearchService {
        // Пересоздаём сервис если ключ изменился
        if _vectorSearchService == nil {
            let service = VectorSearchService(apiKey: settings.openAIApiKey)
            try? service.initialize()
            _vectorSearchService = service
        }
        return _vectorSearchService!
    }

    init(settings: Settings) {
        self.settings = settings
        self.speechRecognitionService = SpeechRecognitionService()
        self.userProfileService = UserProfileService()
        periodicTaskService.chatViewModel = self

        print("🚀 ChatViewModel initialized")

        // Try to load last conversation first
        let conversations = dbManager.getAllConversations()
        print("📊 Found \(conversations.count) existing conversations")

        if let lastConv = conversations.first {
            print("📥 Loading last conversation: \(lastConv.title)")
            currentConversationId = lastConv.id
            conversationTitle = lastConv.title
            loadLastConversation()
        } else {
            print("📝 Creating new conversation")
            // Initialize database and create conversation
            _ = dbManager.createConversation(id: currentConversationId, title: conversationTitle)
        }
    }

    func startRequirementsCollection() {
        conversationMode = .collectingRequirements
        generatedDocument = nil
        messages.removeAll()

        let initialMessage = Message(
            content: "Режим сбора требований активирован. Я буду задавать вам вопросы для формирования технического задания. Когда соберу достаточно информации, я автоматически сформирую полное ТЗ.",
            isFromUser: false
        )
        messages.append(initialMessage)
    }

    func switchToNormalMode() {
        conversationMode = .normal
        generatedDocument = nil
    }
    
    func sendMessage() {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard settings.isConfigured else {
            errorMessage = "API ключ не настроен. Пожалуйста, добавьте его в настройках."
            return
        }

        let userMessage = Message(content: currentMessage, isFromUser: true)
        messages.append(userMessage)

        // Auto-save user message
        autoSaveMessage(userMessage)

        // Auto-update conversation title if this is the first user message
        autoUpdateConversationTitle()

        let messageToSend = currentMessage
        currentMessage = ""
        isLoading = true
        errorMessage = nil

        // Проверяем, запрашивает ли пользователь анализ проекта
        if shouldAnalyzeProject(message: messageToSend) {
            analyzeProject(originalMessage: messageToSend)
            return
        }

        // Инициализируем Yandex Tracker сервис если настроен
        if settings.isYandexTrackerConfigured && !yandexTrackerService.isConnected {
            Task {
                do {
                    try await yandexTrackerService.configure(
                        orgId: settings.yandexTrackerOrgId,
                        token: settings.yandexTrackerToken
                    )
                } catch {
                    print("⚠️ Не удалось подключиться к Yandex Tracker: \(error.localizedDescription)")
                }
            }
        }

        // Выбираем провайдера
        switch settings.selectedProvider {
        case .claude:
            sendToClaude(message: messageToSend)
        case .huggingface:
            sendToHuggingFace(message: messageToSend)
        case .local:
            sendToOllama(message: messageToSend)
        }
    }

    private func sendToHuggingFace(message: String) {
        let _ = Date() // Время начала для метрик

        huggingFaceService.sendRequest(
            model: settings.selectedModel,
            message: message,
            apiKey: settings.huggingFaceApiKey,
            temperature: settings.temperature
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success((let text, let metrics)):
                    let claudeMessage = Message(
                        content: text,
                        isFromUser: false,
                        temperature: self?.settings.temperature,
                        metrics: (
                            responseTime: metrics.responseTime,
                            inputTokens: metrics.inputTokens,
                            outputTokens: metrics.outputTokens,
                            cost: metrics.totalCost,
                            modelName: metrics.modelName
                        )
                    )
                    self?.messages.append(claudeMessage)

                case .failure(let error):
                    self?.handleError("Ошибка HuggingFace: \(error.localizedDescription)")
                    print(error)
                }
            }
        }
    }

    private func sendToOllama(message: String) {
        loadingMessage = "Локальная LLM думает..."

        ollamaService.generateWithMetrics(
            model: "llama3.2:3b",
            prompt: message,
            temperature: settings.temperature
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let (response, responseTime, modelName)):
                    let ollamaMessage = Message(
                        content: response,
                        isFromUser: false,
                        temperature: self?.settings.temperature,
                        metrics: (
                            responseTime: responseTime,
                            inputTokens: nil,  // Ollama doesn't provide token counts
                            outputTokens: nil,
                            cost: 0.0,  // Local LLM is free!
                            modelName: "🏠 \(modelName)"
                        )
                    )
                    self?.messages.append(ollamaMessage)

                case .failure(let error):
                    self?.handleError("Ошибка Ollama: \(error.localizedDescription)\n\nПроверьте, что Ollama запущен: brew services start ollama")
                    print("Ollama error:", error)
                }
            }
        }
    }

    private func sendToClaude(message: String) {
        // Проверяем, нужна ли суммаризация
        if settings.summarizationEnabled && settings.isConfigured {
            // Проверяем длину текста
            if message.count < settings.summarizationMinLength {
                // Текст слишком короткий, пропускаем суммаризацию
                print("⏭️ Текст слишком короткий (\(message.count) символов), минимум: \(settings.summarizationMinLength)")
                loadingMessage = "Claude печатает..."
                sendToClaudeDirectly(message: message)
                return
            }

            // Выбираем провайдера суммаризации
            switch settings.summarizationProvider {
            case .local:
                summarizeWithLocalModel(message: message)
                return
            case .huggingface:
                if !settings.huggingFaceApiKey.isEmpty {
                    summarizeWithHuggingFace(message: message)
                    return
                } else {
                    print("⚠️ HuggingFace API ключ не найден, пропускаем суммаризацию")
                }
            case .claude:
                if !settings.apiKey.isEmpty {
                    summarizeWithClaude(message: message)
                    return
                } else {
                    print("⚠️ Claude API ключ не найден, пропускаем суммаризацию")
                }
            }
        }

        // Если суммаризация не включена или нет ключа, отправляем напрямую
        sendToClaudeDirectly(message: message)
    }

    private func summarizeWithLocalModel(message: String) {
        // Устанавливаем сообщение о суммаризации
        loadingMessage = "Суммаризация текста..."
        summarizationProgress = "Подготовка..."

        // Добавляем системное сообщение о начале суммаризации
        let systemMessage = Message(
            content: "🔄 Суммаризация текста локально (katanemo/Arch-Router-1.5B)...",
            isFromUser: false,
            isSystemMessage: true
        )
        messages.append(systemMessage)

        // Суммаризируем текст локально
        localModelService.summarize(
            text: message,
            progressCallback: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.summarizationProgress = progress
                    self?.loadingMessage = "Локальная суммаризация: \(progress)"
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let summarizedText):
                    // Обновляем системное сообщение с результатом
                    if let index = self.messages.firstIndex(where: { $0.id == systemMessage.id }) {
                        let compressionRatio = Int((1.0 - Double(summarizedText.count) / Double(message.count)) * 100)
                        let updatedMessage = Message(
                            content: "✅ Текст суммаризирован локально (сжатие: \(compressionRatio)%) • Модель: katanemo/Arch-Router-1.5B",
                            isFromUser: false,
                            isSystemMessage: true
                        )
                        self.messages[index] = updatedMessage
                    }

                    print("📝 Оригинальный текст: \(message.count) символов")
                    print("📝 Суммаризированный текст: \(summarizedText.count) символов")

                    // Сбрасываем прогресс суммаризации и меняем сообщение
                    self.summarizationProgress = nil
                    self.loadingMessage = "Claude печатает..."

                    self.sendToClaudeDirectly(message: summarizedText)

                case .failure(let error):
                    // Обновляем системное сообщение с ошибкой
                    if let index = self.messages.firstIndex(where: { $0.id == systemMessage.id }) {
                        let errorMessage = Message(
                            content: "⚠️ Ошибка локальной суммаризации: \(error.localizedDescription). Отправляем оригинальный текст",
                            isFromUser: false,
                            isSystemMessage: true
                        )
                        self.messages[index] = errorMessage
                    }

                    print("⚠️ Ошибка локальной суммаризации: \(error.localizedDescription)")

                    // Сбрасываем прогресс и меняем сообщение
                    self.summarizationProgress = nil
                    self.loadingMessage = "Claude печатает..."

                    self.sendToClaudeDirectly(message: message)
                }
            }
        }
    }

    private func summarizeWithHuggingFace(message: String) {
        // Устанавливаем сообщение о суммаризации
        loadingMessage = "Суммаризация текста..."
        summarizationProgress = "Подготовка..."

        // Добавляем системное сообщение о начале суммаризации
        let systemMessage = Message(
            content: "🔄 Суммаризация текста с помощью HuggingFace (katanemo/Arch-Router-1.5B)...",
            isFromUser: false,
            isSystemMessage: true
        )
        messages.append(systemMessage)

        // Сначала суммаризируем текст
        huggingFaceService.summarize(
            text: message,
            apiKey: settings.huggingFaceApiKey,
            progressCallback: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.summarizationProgress = progress
                    self?.loadingMessage = "Суммаризация: \(progress)"
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let summarizedText):
                    // Обновляем системное сообщение с результатом
                    if let index = self.messages.firstIndex(where: { $0.id == systemMessage.id }) {
                        let compressionRatio = Int((1.0 - Double(summarizedText.count) / Double(message.count)) * 100)
                        let updatedMessage = Message(
                            content: "✅ Текст суммаризирован (сжатие: \(compressionRatio)%) • Модель: katanemo/Arch-Router-1.5B",
                            isFromUser: false,
                            isSystemMessage: true
                        )
                        self.messages[index] = updatedMessage
                    }

                    print("📝 Оригинальный текст: \(message.count) символов")
                    print("📝 Суммаризированный текст: \(summarizedText.count) символов")

                    // Сбрасываем прогресс суммаризации и меняем сообщение
                    self.summarizationProgress = nil
                    self.loadingMessage = "Claude печатает..."

                    self.sendToClaudeDirectly(message: summarizedText)

                case .failure(let error):
                    // Обновляем системное сообщение с ошибкой
                    if let index = self.messages.firstIndex(where: { $0.id == systemMessage.id }) {
                        let errorMessage = Message(
                            content: "⚠️ Ошибка суммаризации, отправляем оригинальный текст",
                            isFromUser: false,
                            isSystemMessage: true
                        )
                        self.messages[index] = errorMessage
                    }

                    print("⚠️ Ошибка суммаризации: \(error.localizedDescription)")

                    // Сбрасываем прогресс и меняем сообщение
                    self.summarizationProgress = nil
                    self.loadingMessage = "Claude печатает..."

                    self.sendToClaudeDirectly(message: message)
                }
            }
        }
    }

    private func summarizeWithClaude(message: String) {
        // Устанавливаем сообщение о суммаризации
        loadingMessage = "Суммаризация текста..."
        summarizationProgress = "Подготовка..."

        // Добавляем системное сообщение о начале суммаризации
        let systemMessage = Message(
            content: "🔄 Суммаризация текста с помощью Claude (claude-sonnet-4-6)...",
            isFromUser: false,
            isSystemMessage: true
        )
        messages.append(systemMessage)

        // Сначала суммаризируем текст
        claudeService.summarize(
            text: message,
            apiKey: settings.apiKey,
            progressCallback: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.summarizationProgress = progress
                    self?.loadingMessage = "Суммаризация: \(progress)"
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let summarizedText):
                    // Обновляем системное сообщение с результатом
                    if let index = self.messages.firstIndex(where: { $0.id == systemMessage.id }) {
                        let compressionRatio = Int((1.0 - Double(summarizedText.count) / Double(message.count)) * 100)
                        let updatedMessage = Message(
                            content: "✅ Текст суммаризирован (сжатие: \(compressionRatio)%) • Модель: claude-sonnet-4-6",
                            isFromUser: false,
                            isSystemMessage: true
                        )
                        self.messages[index] = updatedMessage
                    }

                    print("📝 Оригинальный текст: \(message.count) символов")
                    print("📝 Суммаризированный текст: \(summarizedText.count) символов")

                    // Сбрасываем прогресс суммаризации и меняем сообщение
                    self.summarizationProgress = nil
                    self.loadingMessage = "Claude печатает..."

                    self.sendToClaudeDirectly(message: summarizedText)

                case .failure(let error):
                    // Обновляем системное сообщение с ошибкой
                    if let index = self.messages.firstIndex(where: { $0.id == systemMessage.id }) {
                        let errorMessage = Message(
                            content: "⚠️ Ошибка суммаризации, отправляем оригинальный текст",
                            isFromUser: false,
                            isSystemMessage: true
                        )
                        self.messages[index] = errorMessage
                    }

                    print("⚠️ Ошибка суммаризации: \(error.localizedDescription)")

                    // Сбрасываем прогресс и меняем сообщение
                    self.summarizationProgress = nil
                    self.loadingMessage = "Claude печатает..."

                    self.sendToClaudeDirectly(message: message)
                }
            }
        }
    }

    private func sendToClaudeDirectly(message: String) {
        let startTime = Date()

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            handleError("Неверный URL API")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("\(settings.apiKey)", forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 60.0 // Увеличиваем таймаут для tool use
        
        let systemPrompt: String
        if conversationMode == .collectingRequirements {
            systemPrompt = """
                Вы - бизнес-аналитик, собирающий требования для технического задания. ВСЕГДА отвечайте в формате JSON.

                ВАЖНО: Задавайте ТОЛЬКО ОДИН вопрос за раз. Не задавайте несколько вопросов одновременно.

                Ваша задача:
                1. Задавайте по одному уточняющему вопросу для понимания проекта
                2. Собирайте информацию о: целях, функциональности, аудитории, технологиях, сроках, бюджете
                3. После каждого ответа пользователя, задавайте следующий вопрос
                4. Когда соберете достаточно информации (минимум 5-7 ответов), установите "ready_to_generate": true

                Примеры хороших вопросов (по одному):
                - "Как называется ваш проект?"
                - "Какая основная цель этого проекта?"
                - "Кто будет использовать это приложение?"
                - "Какие ключевые функции должны быть?"

                Формат ответа:
                {
                    "response": "ТОЛЬКО ОДИН вопрос здесь",
                    "collected_info": {
                        "project_name": "название проекта или null",
                        "goals": "цели или null",
                        "features": ["функция1", "функция2"] или [],
                        "target_audience": "целевая аудитория или null",
                        "technologies": ["технология1"] или [],
                        "timeline": "сроки или null",
                        "budget": "бюджет или null"
                    },
                    "ready_to_generate": false,
                    "completion_percentage": 30
                }

                Когда ready_to_generate == true, добавьте поле "final_document" с полным ТЗ в формате markdown.
                """
        } else {
            // Формируем system prompt в зависимости от наличия инструментов
            let hasTrackerTools = settings.enableYandexTrackerTools && settings.isYandexTrackerConfigured && yandexTrackerService.isConnected
            let hasPeriodicTasks = settings.enablePeriodicTaskTools
            let hasSimulatorTools = settings.enableSimulatorTools

            // Создаем список возможностей
            var capabilities: [String] = []
            if hasTrackerTools {
                capabilities.append("доступом к Yandex Tracker")
            }
            if hasPeriodicTasks {
                capabilities.append("возможностью создания периодических задач")
            }
            if hasSimulatorTools {
                capabilities.append("управлением iOS симулятором")
            }

            let capabilitiesText = capabilities.isEmpty ? "полезный ассистент" : "полезный ассистент с " + capabilities.joined(separator: ", ")

            // Формируем описание инструментов
            var toolsDescription = ""

            if hasTrackerTools {
                toolsDescription += """

                    📋 YANDEX TRACKER:
                    Когда пользователь спрашивает о задачах, статистике или других данных из Yandex Tracker, используйте доступные инструменты для получения актуальной информации.
                    """
            }

            if hasPeriodicTasks {
                toolsDescription += """

                    ⏰ ПЕРИОДИЧЕСКИЕ ЗАДАЧИ:
                    Когда пользователь просит периодически присылать информацию (например: "Пиши мне погоду каждый час", "Присылай обновления погоды раз в час"), используйте инструменты для создания автоматических периодических задач.
                    """
            }

            if hasSimulatorTools {
                toolsDescription += """

                    📱 iOS SIMULATOR:
                    У вас есть полный контроль над iOS симуляторами на этом Mac. Вы можете:
                    - Получать список доступных симуляторов (list_simulators)
                    - Запускать симулятор (boot_simulator) - указывайте имя или UDID
                    - Останавливать симулятор (shutdown_simulator)
                    - Устанавливать приложения (install_app)
                    - Запускать приложения (launch_app)
                    - Делать скриншоты (take_screenshot)
                    - Получать список установленных приложений (list_apps) - показывает ВСЕ установленные приложения на симуляторе, включая системные и пользовательские

                    ВАЖНО: У вас ЕСТЬ возможность получить список установленных приложений через инструмент list_apps.

                    Когда пользователь просит что-то сделать с симулятором (запустить, сделать скриншот, установить приложение, показать список приложений и т.д.), ВСЕГДА используйте соответствующие инструменты.
                    """
            }

            // Добавляем профиль пользователя в начало prompt
            let userProfileContext = userProfileService.profile.toSystemPrompt()

            systemPrompt = """
                Вы - \(capabilitiesText).
                \(toolsDescription)

                \(userProfileContext.isEmpty ? "" : userProfileContext + "\n")
                Для обычных вопросов отвечайте как обычный ассистент.
                Используйте естественный язык для всех ответов.
                """

            print("📋 System Prompt:")
            print(systemPrompt)
        }

        // Формируем историю сообщений для контекста (с поддержкой компрессии)
        var messagesArray = buildMessageArray()

        // Добавляем текущее сообщение
        messagesArray.append([
            "role": "user",
            "content": message
        ])

        print("📨 Отправляем \(messagesArray.count) сообщений в историю (включая текущее)")

        // Добавляем инструменты если Yandex Tracker настроен
        var requestBody: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 2000,
            "temperature": settings.temperature,
            "system": systemPrompt,
            "messages": messagesArray
        ]
        
        // Добавляем инструменты
        var allTools: [ClaudeTool] = []

        // Инструменты Yandex Tracker если включены и настроены
        if settings.enableYandexTrackerTools && settings.isYandexTrackerConfigured && yandexTrackerService.isConnected {
            allTools.append(contentsOf: YandexTrackerToolsProvider.getTools())
        }

        // Инструменты периодических задач если включены
        if settings.enablePeriodicTaskTools {
            allTools.append(contentsOf: PeriodicTaskToolsProvider.getTools())
        }

        // Инструменты iOS Simulator если включены
        if settings.enableSimulatorTools {
            allTools.append(contentsOf: SimulatorToolsProvider.getTools())
        }

        // Формируем JSON для tools если есть хотя бы один инструмент
        if !allTools.isEmpty {
            print("📦 Отправляю Claude \(allTools.count) инструментов:")
            allTools.forEach { tool in
                print("  - \(tool.name): \(tool.description.prefix(60))...")
            }

            let toolsJson = allTools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": [
                        "type": "object",
                        "properties": tool.input_schema.properties.mapValues { property in
                            [
                                "type": property.type,
                                "description": property.description
                            ]
                        },
                        "required": tool.input_schema.required ?? []
                    ]
                ]
            }
            requestBody["tools"] = toolsJson
        } else {
            print("⚠️ Нет доступных инструментов для отправки Claude")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            handleError("Ошибка при создании запроса: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let responseTime = Date().timeIntervalSince(startTime)

            DispatchQueue.main.async {
                // НЕ сбрасываем isLoading здесь - будем сбрасывать после обработки
                // self?.isLoading = false

                if let error = error {
                    self?.isLoading = false
                    let nsError = error as NSError
                    var errorMessage = "Ошибка сети: \(error.localizedDescription)"

                    switch nsError.code {
                    case -1003:
                        errorMessage = "Сервер не найден. Проверьте подключение к интернету и попробуйте снова."
                    case -1001:
                        errorMessage = "Превышено время ожидания. Попробуйте снова."
                    case -1009:
                        errorMessage = "Нет подключения к интернету."
                    case 401:
                        errorMessage = "Неверный API ключ. Проверьте настройки."
                    default:
                        errorMessage = "Ошибка сети: \(error.localizedDescription)"
                    }

                    self?.handleError(errorMessage)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status Code: \(httpResponse.statusCode)")
                    print("✅ Response headers: \(httpResponse.allHeaderFields)")

                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("📄 Response body: \(errorString)")
                    }

                    if httpResponse.statusCode == 401 {
                        self?.isLoading = false
                        self?.handleError("Неверный API ключ. Проверьте настройки.")
                        return
                    } else if httpResponse.statusCode >= 400 {
                        self?.isLoading = false
                        self?.handleError("Ошибка сервера: \(httpResponse.statusCode)")
                        return
                    }
                }

                guard let data = data else {
                    self?.isLoading = false
                    self?.handleError("Нет данных в ответе")
                    return
                }

                self?.processClaudeResponse(data: data, responseTime: responseTime, originalMessage: message)
            }
        }.resume()
    }
    
    private func processClaudeResponse(data: Data, responseTime: TimeInterval, originalMessage: String) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let content = json["content"] as? [[String: Any]] {
                    
                    // Извлекаем usage информацию
                    var inputTokens: Int? = nil
                    var outputTokens: Int? = nil
                    var cost: Double? = nil

                    if let usage = json["usage"] as? [String: Any] {
                        inputTokens = usage["input_tokens"] as? Int
                        outputTokens = usage["output_tokens"] as? Int

                        // Рассчитываем стоимость для Claude 3.7 Sonnet
                        if let input = inputTokens, let output = outputTokens {
                            let inputCost = Double(input) * 0.000003  // $3 per 1M input tokens
                            let outputCost = Double(output) * 0.000015  // $15 per 1M output tokens
                            cost = inputCost + outputCost
                        }
                    }
                    
                    // Проверяем есть ли tool_use в ответе
                    var hasToolUse = false
                    for contentItem in content {
                        if contentItem["type"] as? String == "tool_use" {
                            hasToolUse = true
                            break
                        }
                    }
                    
                    if hasToolUse {
                        // Обрабатываем tool use - isLoading остается true
                        // Он будет сброшен в конце handleToolUse
                        Task {
                            await handleToolUse(content: content, responseTime: responseTime, inputTokens: inputTokens, outputTokens: outputTokens, cost: cost, originalMessage: originalMessage)
                        }
                    } else {
                        // Обычный текстовый ответ - можно сбросить isLoading
                        isLoading = false

                        if let firstContent = content.first,
                           let text = firstContent["text"] as? String {

                            if conversationMode == .collectingRequirements {
                                processRequirementsResponse(
                                    text: text,
                                    responseTime: responseTime,
                                    inputTokens: inputTokens,
                                    outputTokens: outputTokens,
                                    cost: cost
                                )
                            } else {
                                let claudeMessage = Message(
                                    content: text,
                                    isFromUser: false,
                                    temperature: settings.temperature,
                                    metrics: (
                                        responseTime: responseTime,
                                        inputTokens: inputTokens,
                                        outputTokens: outputTokens,
                                        cost: cost,
                                        modelName: "claude-sonnet-4-6"
                                    )
                                )
                                messages.append(claudeMessage)

                                // Auto-save message
                                autoSaveMessage(claudeMessage)

                                // Check if compression is needed
                                compressHistoryIfNeeded()
                            }
                        }
                    }
                } else if let error = json["error"] as? [String: Any],
                          let message = error["message"] as? String {
                    isLoading = false
                    handleError("Ошибка API: \(message)")
                } else {
                    // Добавляем отладочную информацию
                    print("🔍 Неожиданный формат ответа от Claude:")
                    print("📄 JSON структура: \(json.keys)")
                    if let content = json["content"] {
                        print("📄 Content type: \(type(of: content))")
                        print("📄 Content value: \(content)")
                    }
                    if let rawContent = json["content"] as? [Any] {
                        print("📄 Raw content array: \(rawContent)")
                    }

                    // Пытаемся обработать как обычный текстовый ответ
                    if let content = json["content"] as? [Any], let firstContent = content.first as? [String: Any] {
                        if let text = firstContent["text"] as? String {
                            isLoading = false
                            let claudeMessage = Message(
                                content: text,
                                isFromUser: false,
                                temperature: settings.temperature,
                                metrics: (
                                    responseTime: responseTime,
                                    inputTokens: nil,
                                    outputTokens: nil,
                                    cost: nil,
                                    modelName: "claude-sonnet-4-6"
                                )
                            )
                            messages.append(claudeMessage)
                            return
                        }
                    }

                    isLoading = false
                    handleError("Неожиданный формат ответа. Проверьте консоль для отладочной информации.")
                }
            }
        } catch {
            isLoading = false
            handleError("Ошибка при обработке ответа: \(error.localizedDescription)")
        }
    }

    private func processRequirementsResponse(
        text: String,
        responseTime: TimeInterval,
        inputTokens: Int?,
        outputTokens: Int?,
        cost: Double?
    ) {
        // Парсим JSON ответ от Claude
        guard let jsonData = text.data(using: .utf8),
              let responseJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let response = responseJson["response"] as? String else {
            let claudeMessage = Message(
                content: text,
                isFromUser: false,
                temperature: settings.temperature,
                metrics: (
                    responseTime: responseTime,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cost: cost,
                    modelName: "claude-sonnet-4-6"
                )
            )
            messages.append(claudeMessage)
            return
        }

        // Добавляем ответ Claude в чат
        let claudeMessage = Message(
            content: response,
            isFromUser: false,
            temperature: settings.temperature,
            metrics: (
                responseTime: responseTime,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cost: cost,
                modelName: "claude-sonnet-4-6"
            )
        )
        messages.append(claudeMessage)

        // Проверяем, готов ли документ
        if let readyToGenerate = responseJson["ready_to_generate"] as? Bool,
           readyToGenerate,
           let finalDocument = responseJson["final_document"] as? String {

            // Сохраняем сгенерированный документ
            generatedDocument = finalDocument

            // Уведомляем пользователя
            let documentMessage = Message(
                content: "✅ Техническое задание сформировано! Вы можете его просмотреть.",
                isFromUser: false
            )
            messages.append(documentMessage)
        }

        // Опционально: показываем прогресс
        if let percentage = responseJson["completion_percentage"] as? Int {
            print("📊 Прогресс сбора требований: \(percentage)%")
        }
    }
    
    private func handleToolUse(
        content: [[String: Any]],
        responseTime: TimeInterval,
        inputTokens: Int?,
        outputTokens: Int?,
        cost: Double?,
        originalMessage: String
    ) async {
        print("🔧 Обработка tool_use от Claude")
        print("📄 Количество content элементов: \(content.count)")
        
        // Собираем результаты выполнения инструментов
        var toolResults: [[String: Any]] = []
        
        for (index, contentItem) in content.enumerated() {
            print("📄 Content[\(index)]: \(contentItem)")
            
            if contentItem["type"] as? String == "tool_use",
               let toolUseId = contentItem["id"] as? String,
               let toolName = contentItem["name"] as? String,
               let toolInput = contentItem["input"] as? [String: Any] {
                
                print("🔧 Выполняем инструмент: \(toolName)")
                print("📄 ID: \(toolUseId)")
                print("📄 Input: \(toolInput)")

                do {
                    // Определяем тип инструмента и выполняем
                    let result: String

                    // Проверяем, это инструмент Yandex Tracker или Periodic Task
                    if toolName.hasPrefix("get_yandex_tracker") {
                        print("➡️ Распознан как Yandex Tracker инструмент")
                        // Обновляем индикатор загрузки
                        await MainActor.run {
                            self.loadingMessage = "📊 Yandex Tracker API запрашивает данные..."
                        }
                        // Yandex Tracker инструмент
                        result = try await YandexTrackerToolsProvider.executeTool(
                            name: toolName,
                            input: toolInput,
                            trackerService: yandexTrackerService
                        )
                    } else if toolName.contains("weather") || toolName.contains("task") {
                        print("➡️ Распознан как Periodic Task инструмент")
                        // Periodic Task инструмент
                        result = try await PeriodicTaskToolsProvider.executeTool(
                            name: toolName,
                            input: toolInput,
                            periodicTaskService: periodicTaskService,
                            settings: settings,
                            progressCallback: { [weak self] progress in
                                DispatchQueue.main.async {
                                    self?.loadingMessage = progress
                                }
                            }
                        )
                    } else if toolName.contains("simulator") || toolName.contains("_app") {
                        print("➡️ Распознан как iOS Simulator инструмент")
                        // iOS Simulator инструмент
                        result = try await SimulatorToolsProvider.executeTool(
                            name: toolName,
                            input: toolInput,
                            simulatorService: simulatorService,
                            progressCallback: { [weak self] progress in
                                DispatchQueue.main.async {
                                    self?.loadingMessage = progress
                                }
                            }
                        )
                    } else {
                        print("⚠️ Не распознан тип инструмента: \(toolName)")
                        result = "❌ Неизвестный тип инструмента: \(toolName)"
                    }

                    print("✅ Инструмент выполнен успешно")
                    print("📄 Результат: \(result)")

                    // Добавляем результат
                    toolResults.append([
                        "type": "tool_result",
                        "tool_use_id": toolUseId,
                        "content": result,
                        "is_error": false
                    ])

                } catch {
                    print("❌ Ошибка выполнения инструмента: \(error.localizedDescription)")

                    // Ошибка выполнения инструмента
                    toolResults.append([
                        "type": "tool_result",
                        "tool_use_id": toolUseId,
                        "content": "Ошибка выполнения инструмента: \(error.localizedDescription)",
                        "is_error": true
                    ])
                }
            }
        }
        
        print("📄 Итого результатов инструментов: \(toolResults.count)")

        // Обновляем индикатор - все инструменты выполнены, Claude формирует ответ
        await MainActor.run {
            self.loadingMessage = "🤖 Claude анализирует результаты и формирует ответ..."
        }

        // Отправляем результаты обратно Claude
        await sendToolResultsToClaude(
            toolResults: toolResults,
            originalMessage: originalMessage,
            responseTime: responseTime,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cost: cost
        )
    }

    private func sendToolResultsToClaude(
        toolResults: [[String: Any]],
        originalMessage: String,
        responseTime: TimeInterval,
        inputTokens: Int?,
        outputTokens: Int?,
        cost: Double?
    ) async {
        print("📤 Отправляем результаты инструментов обратно Claude")
        print("📄 Количество результатов: \(toolResults.count)")
        print("📄 Исходное сообщение: \(originalMessage)")
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            handleError("Неверный URL API")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("\(settings.apiKey)", forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 60.0

        // Формируем сообщения для отправки
        var messagesArray: [[String: Any]] = []
        
        // Добавляем последние несколько сообщений из истории для контекста
        let recentMessages = Array(messages.suffix(4)) // Последние 4 сообщения
        print("📄 Добавляем \(recentMessages.count) последних сообщений для контекста")
        
        for msg in recentMessages {
            messagesArray.append([
                "role": msg.isFromUser ? "user" : "assistant",
                "content": msg.content
            ])
        }
        
        // Добавляем исходное сообщение пользователя (если его еще нет в истории)
        if !recentMessages.contains(where: { $0.content == originalMessage && $0.isFromUser }) {
            print("📄 Добавляем исходное сообщение пользователя")
            messagesArray.append([
                "role": "user",
                "content": originalMessage
            ])
        }
        
        // Добавляем результаты выполнения инструментов
        for toolResult in toolResults {
            print("📄 Добавляем результат инструмента: \(toolResult)")
            // tool_result не нужно добавлять в messages - это отдельный тип сообщения
            // Вместо этого мы отправим их как отдельные сообщения в правильном формате
        }

        // Формируем финальное сообщение с результатами инструментов
        var finalMessage = originalMessage + "\n\nРезультаты выполнения инструментов:\n"
        
        for toolResult in toolResults {
            if let content = toolResult["content"] as? String {
                finalMessage += "\n\(content)\n"
            }
        }
        
        // Добавляем финальное сообщение с результатами
        messagesArray.append([
            "role": "user",
            "content": finalMessage
        ])

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 2000,
            "temperature": settings.temperature,
            "system": "Вы - полезный ассистент с доступом к инструментам Yandex Tracker. Используйте результаты выполнения инструментов для ответа пользователю на естественном языке.",
            "messages": messagesArray
        ]
        
        print("📄 Итого сообщений для отправки: \(messagesArray.count)")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            handleError("Ошибка при создании запроса: \(error.localizedDescription)")
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                // НЕ сбрасываем isLoading здесь - будем сбрасывать после обработки ответа

                if let error = error {
                    self?.isLoading = false
                    print("❌ Ошибка сети при отправке результатов инструментов: \(error.localizedDescription)")
                    self?.handleError("Ошибка сети: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    self?.isLoading = false
                    print("❌ Нет данных в ответе от Claude")
                    self?.handleError("Нет данных в ответе")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 HTTP статус ответа от Claude: \(httpResponse.statusCode)")
                    if httpResponse.statusCode >= 400 {
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("❌ Ошибка HTTP: \(responseString)")
                        }
                    }
                }

                print("📄 Получен финальный ответ от Claude, размер: \(data.count) байт")

                // Обрабатываем финальный ответ от Claude
                self?.processFinalClaudeResponse(data: data, responseTime: responseTime, inputTokens: inputTokens, outputTokens: outputTokens, cost: cost)
            }
        }.resume()
    }
    
    private func processFinalClaudeResponse(
        data: Data,
        responseTime: TimeInterval,
        inputTokens: Int?,
        outputTokens: Int?,
        cost: Double?
    ) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 Финальный ответ от Claude:")
                print("📄 JSON ключи: \(json.keys)")
                
                if let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {

                    print("📄 Найден текстовый ответ: \(text)")

                    isLoading = false // Финальный ответ получен, сбрасываем индикатор

                    let claudeMessage = Message(
                        content: text,
                        isFromUser: false,
                        temperature: settings.temperature,
                        metrics: (
                            responseTime: responseTime,
                            inputTokens: inputTokens,
                            outputTokens: outputTokens,
                            cost: cost,
                            modelName: "claude-sonnet-4-6"
                        )
                    )
                    messages.append(claudeMessage)

                    // Auto-save message
                    autoSaveMessage(claudeMessage)

                    // Check if compression is needed
                    compressHistoryIfNeeded()
                } else {
                    print("❌ Не удалось извлечь текстовый ответ из финального ответа")
                    print("📄 Content: \(json["content"] ?? "nil")")

                    // Пытаемся обработать как обычный ответ
                    if let content = json["content"] as? [Any], let firstContent = content.first as? [String: Any] {
                        if let text = firstContent["text"] as? String {
                            print("📄 Найден альтернативный текстовый ответ: \(text)")

                            isLoading = false // Финальный ответ получен, сбрасываем индикатор

                            let claudeMessage = Message(
                                content: text,
                                isFromUser: false,
                                temperature: settings.temperature,
                                metrics: (
                                    responseTime: responseTime,
                                    inputTokens: inputTokens,
                                    outputTokens: outputTokens,
                                    cost: cost,
                                    modelName: "claude-sonnet-4-6"
                                )
                            )
                            messages.append(claudeMessage)

                            // Auto-save message
                            autoSaveMessage(claudeMessage)

                            // Check if compression is needed
                            compressHistoryIfNeeded()
                            return
                        }
                    }

                    handleError("Неожиданный формат финального ответа. Проверьте консоль для отладочной информации.")
                }
            } else {
                handleError("Не удалось распарсить JSON ответ")
            }
        } catch {
            handleError("Ошибка при обработке финального ответа: \(error.localizedDescription)")
        }
    }

    private func handleError(_ message: String) {
        errorMessage = message
        isLoading = false
    }
    
    func clearChat() {
        messages.removeAll()
        errorMessage = nil
        compressedHistory = CompressedConversationHistory()
        compressionStats = CompressionStats()
    }

    // MARK: - History Compression

    /// Automatically compress history if threshold is reached
    private func compressHistoryIfNeeded() {
        guard settings.historyCompressionEnabled else { return }
        guard !isCompressing else { return }

        // Update compression service configuration
        compressionService.compressionThreshold = settings.compressionThreshold
        compressionService.recentMessagesToKeep = settings.recentMessagesToKeep

        // Filter out system messages for compression check
        let contentMessages = messages.filter { !$0.isSystemMessage }

        guard compressionService.shouldCompress(messageCount: contentMessages.count) else { return }

        Task {
            await performCompression()
        }
    }

    /// Perform actual compression
    private func performCompression() async {
        await MainActor.run {
            isCompressing = true
            loadingMessage = "Сжимаю историю диалога..."
        }

        do {
            // Compress history
            let newCompressedHistory = try await compressionService.compressHistory(
                compressedHistory,
                allMessages: messages
            )

            await MainActor.run {
                // Update compressed history
                self.compressedHistory = newCompressedHistory

                // Update statistics
                if let lastSummary = newCompressedHistory.summaries.last {
                    compressionStats.recordCompression(summary: lastSummary)
                }

                // Update messages to keep only recent ones
                let contentMessages = messages.filter { !$0.isSystemMessage }
                let recentCount = min(settings.recentMessagesToKeep, contentMessages.count)
                let recentMessages = Array(contentMessages.suffix(recentCount))

                // Keep system messages and recent content messages
                messages = messages.filter { $0.isSystemMessage } + recentMessages

                isCompressing = false
                loadingMessage = "Claude печатает..."

                print("✅ История сжата. Сообщений: \(contentMessages.count) → \(recentMessages.count)")
                print("📊 Сэкономлено токенов: \(compressionStats.totalTokensSaved)")

                // Auto-save compression data
                autoSaveCompressionData()
            }
        } catch {
            await MainActor.run {
                isCompressing = false
                loadingMessage = "Claude печатает..."
                print("❌ Ошибка сжатия истории: \(error.localizedDescription)")
            }
        }
    }

    /// Get message array for API calls (with compression support)
    private func buildMessageArray() -> [[String: String]] {
        if settings.historyCompressionEnabled && !compressedHistory.summaries.isEmpty {
            // Use compressed history
            return compressedHistory.buildMessageArray()
        } else {
            // Use regular history
            var messagesArray: [[String: String]] = []

            for msg in messages {
                if msg.isSystemMessage {
                    continue
                }

                messagesArray.append([
                    "role": msg.isFromUser ? "user" : "assistant",
                    "content": msg.content
                ])
            }

            return messagesArray
        }
    }

    // MARK: - Project Analysis

    /// Проверяет, является ли сообщение запросом на анализ проекта
    private func shouldAnalyzeProject(message: String) -> Bool {
        let lowercased = message.lowercased()

        let keywords = [
            "проанализируй проект",
            "анализ проекта",
            "найди баги",
            "найди ошибки",
            "структура проекта",
            "архитектура проекта",
            "построй структуру",
            "построить структуру",
            "покажи структуру",
            "scan project",
            "analyze project",
            "find bugs",
            "project structure",
            "build structure"
        ]

        let shouldAnalyze = keywords.contains { lowercased.contains($0) }

        if shouldAnalyze {
            print("✅ Детектирован запрос на анализ проекта: '\(message)'")
        }

        return shouldAnalyze
    }

    /// Определяет тип запроса на анализ
    private func getAnalysisType(from message: String) -> ProjectAnalyzer.AnalysisType {
        let lowercased = message.lowercased()

        // Проверяем запросы на структуру
        if lowercased.contains("структур") || lowercased.contains("архитектур") ||
           lowercased.contains("structure") || lowercased.contains("построй") ||
           lowercased.contains("покажи") || lowercased.contains("build") {
            print("📐 Тип анализа: Структура")
            return .structure
        }

        // Проверяем запросы на баги
        if lowercased.contains("баг") || lowercased.contains("ошиб") ||
           lowercased.contains("проблем") || lowercased.contains("bug") ||
           lowercased.contains("error") || lowercased.contains("issue") {
            print("🐛 Тип анализа: Баги")
            return .bugs
        }

        // Полный анализ по умолчанию
        print("📊 Тип анализа: Полный")
        return .full
    }

    /// Извлекает путь к проекту из сообщения пользователя
    private func extractProjectPath(from message: String) -> String? {
        // Ищем паттерны указания пути
        // Примеры: "проанализируй /path/to/project", "структура ~/Documents/MyProject"

        let patterns = [
            #"(/[\w\-/\.]+)"#,           // Unix paths: /Users/name/project
            #"(~/[\w\-/\.]+)"#,          // Home paths: ~/Documents/project
            #"([A-Z]:\\[\w\-\\\.]+)"#    // Windows paths: C:\Users\project
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
               let range = Range(match.range(at: 1), in: message) {
                var path = String(message[range])

                // Раскрываем ~ в полный путь
                if path.hasPrefix("~") {
                    path = path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
                }

                print("📂 Извлечён путь из сообщения: \(path)")
                return path
            }
        }

        return nil
    }

    /// Выполняет автоматический анализ проекта
    private func analyzeProject(originalMessage: String) {
        // Определяем тип анализа
        let analysisType = getAnalysisType(from: originalMessage)

        // Извлекаем путь к проекту (если указан)
        let customPath = extractProjectPath(from: originalMessage)

        // Добавляем системное сообщение о начале анализа
        let projectInfo = customPath != nil ? "проект по пути \(customPath!)" : "проект AIAdventChatV2"
        let systemMessage = Message(
            content: "🔍 Сканирую \(projectInfo)...",
            isFromUser: false,
            isSystemMessage: true
        )
        messages.append(systemMessage)

        // Выполняем анализ в фоновом потоке
        Task.detached {
            // Генерируем отчёт в зависимости от типа запроса
            let report = ProjectAnalyzer.generateReport(type: analysisType, customPath: customPath)

            // Возвращаемся в главный поток для обновления UI
            await MainActor.run {
                // Обновляем системное сообщение
                if let index = self.messages.firstIndex(where: { $0.id == systemMessage.id }) {
                    let updatedMessage = Message(
                        content: "✅ Проект проанализирован. Отправляю данные Claude...",
                        isFromUser: false,
                        isSystemMessage: true
                    )
                    self.messages[index] = updatedMessage
                }

                // Отправляем собранные данные Claude
                self.sendToClaudeDirectly(message: report)
            }
        }
    }

    // MARK: - Long-term Memory Persistence

    /// Auto-save message to database
    private func autoSaveMessage(_ message: Message) {
        guard isAutoSavingEnabled else { return }

        Task.detached { [weak self] in
            guard let self = self else { return }

            let success = self.dbManager.saveMessage(message, conversationId: self.currentConversationId)

            if success {
                print("💾 Message auto-saved to database")
            } else {
                print("⚠️ Failed to auto-save message")
            }
        }
    }

    /// Auto-save compression data
    private func autoSaveCompressionData() {
        guard isAutoSavingEnabled else { return }

        Task.detached { [weak self] in
            guard let self = self else { return }

            // Save summaries
            for summary in self.compressedHistory.summaries {
                _ = self.dbManager.saveSummary(summary, conversationId: self.currentConversationId)
            }

            // Save compression stats
            _ = self.dbManager.saveCompressionStats(self.compressionStats, conversationId: self.currentConversationId)

            print("💾 Compression data auto-saved")
        }
    }

    /// Load last conversation from database
    func loadLastConversation() {
        let conversations = dbManager.getAllConversations()

        guard let lastConversation = conversations.first else {
            print("ℹ️ No previous conversations found")
            return
        }

        print("📥 Loading last conversation: \(lastConversation.title)")

        currentConversationId = lastConversation.id
        conversationTitle = lastConversation.title

        // Load messages
        messages = dbManager.loadMessages(conversationId: currentConversationId)

        // Load summaries
        let summaries = dbManager.loadSummaries(conversationId: currentConversationId)
        compressedHistory.summaries = summaries

        // Load compression stats
        if let stats = dbManager.loadCompressionStats(conversationId: currentConversationId) {
            compressionStats = stats
        }

        print("✅ Loaded \(messages.count) messages, \(summaries.count) summaries")
    }

    /// Create new conversation
    func createNewConversation(title: String? = nil) {
        // Save current conversation state before switching
        autoSaveCompressionData()

        // Reset current state
        currentConversationId = UUID().uuidString
        conversationTitle = title ?? "Разговор от \(Date().formatted(date: .abbreviated, time: .shortened))"
        messages.removeAll()
        compressedHistory = CompressedConversationHistory()
        compressionStats = CompressionStats()
        errorMessage = nil
        generatedDocument = nil

        // Create in database
        _ = dbManager.createConversation(id: currentConversationId, title: conversationTitle)

        print("📝 New conversation created: \(conversationTitle)")
    }

    /// Load specific conversation
    func loadConversation(id: String) {
        // Save current state
        autoSaveCompressionData()

        currentConversationId = id

        // Load from database
        messages = dbManager.loadMessages(conversationId: id)
        let summaries = dbManager.loadSummaries(conversationId: id)
        compressedHistory.summaries = summaries

        if let stats = dbManager.loadCompressionStats(conversationId: id) {
            compressionStats = stats
        } else {
            compressionStats = CompressionStats()
        }

        // Get conversation title
        let conversations = dbManager.getAllConversations()
        if let conversation = conversations.first(where: { $0.id == id }) {
            conversationTitle = conversation.title
        }

        print("✅ Loaded conversation: \(conversationTitle)")
    }

    /// Auto-update conversation title based on first user message
    private func autoUpdateConversationTitle() {
        // Only update if it's a default title
        let isDefaultTitle = conversationTitle.hasPrefix("Разговор от") || conversationTitle == "Новый разговор"

        guard isDefaultTitle,
              let firstUserMessage = messages.first(where: { $0.isFromUser }) else {
            return
        }

        // Create a smart title from first message (first 50 chars)
        let content = firstUserMessage.content
        let maxLength = 50
        let newTitle = if content.count > maxLength {
            String(content.prefix(maxLength)) + "..."
        } else {
            content
        }

        conversationTitle = newTitle
        _ = dbManager.updateConversationTitle(id: currentConversationId, title: newTitle)
    }

    /// Export current conversation to JSON
    func exportCurrentConversation() -> URL? {
        let createdAt = messages.first?.timestamp ?? Date()
        let updatedAt = messages.last?.timestamp ?? Date()

        return jsonManager.exportConversation(
            id: currentConversationId,
            title: conversationTitle,
            messages: messages,
            summaries: compressedHistory.summaries,
            compressionStats: compressionStats,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Create full backup of all conversations
    func createFullBackup() -> URL? {
        // Ensure current conversation is saved
        autoSaveCompressionData()

        return jsonManager.createFullBackup()
    }

    /// Import conversation from JSON file
    func importConversation(from url: URL) -> Bool {
        guard let imported = jsonManager.importConversation(from: url) else {
            return false
        }

        // Save current state first
        autoSaveCompressionData()

        // Import as new conversation
        currentConversationId = imported.id
        conversationTitle = imported.title
        messages = imported.messages
        compressedHistory.summaries = imported.summaries
        compressionStats = imported.compressionStats ?? CompressionStats()

        // Save to database
        _ = dbManager.createConversation(id: currentConversationId, title: conversationTitle)

        for message in messages {
            _ = dbManager.saveMessage(message, conversationId: currentConversationId)
        }

        for summary in compressedHistory.summaries {
            _ = dbManager.saveSummary(summary, conversationId: currentConversationId)
        }

        if let stats = imported.compressionStats {
            _ = dbManager.saveCompressionStats(stats, conversationId: currentConversationId)
        }

        print("✅ Conversation imported: \(conversationTitle)")
        return true
    }

    /// Get all saved conversations
    func getAllSavedConversations() -> [(id: String, title: String, updatedAt: Date, messageCount: Int)] {
        return dbManager.getAllConversations()
    }

    /// Delete conversation
    func deleteConversation(id: String) -> Bool {
        if id == currentConversationId {
            createNewConversation()
        }

        return dbManager.deleteConversation(id: id)
    }

    // MARK: - Text Processing Pipeline

    /// Process text through cleaning and compression pipeline
    func processTextThroughPipeline(_ text: String) {
        isProcessingText = true
        errorMessage = nil

        Task {
            do {
                let result = try await textPipeline.process(text)

                await MainActor.run {
                    pipelineResult = result
                    showingPipelineResult = true
                    isProcessingText = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Pipeline error: \(error.localizedDescription)"
                    isProcessingText = false
                }
            }
        }
    }

    /// Use processed text in message
    func useProcessedText() {
        guard let result = pipelineResult else { return }
        currentMessage = result.compressedText
        showingPipelineResult = false
    }

    // MARK: - Vector Search

    /// Reset vector search service (call when OpenAI API key changes)
    func resetVectorSearchService() {
        _vectorSearchService?.shutdown()
        _vectorSearchService = nil
        print("🔄 Vector search service reset")
    }

    /// Index project documentation
    func indexProjectDocumentation(projectPath: String) {
        isIndexing = true
        indexingProgress = "Starting indexing..."
        errorMessage = nil

        Task {
            do {
                let stats = try await vectorSearchService.indexProjectDocumentation(
                    projectPath: projectPath
                ) { file, current, total in
                    Task { @MainActor [weak self] in
                        self?.indexingProgress = "Indexing \(current)/\(total): \(file)"
                    }
                }

                await MainActor.run {
                    indexingStatistics = stats
                    indexingProgress = "✅ Indexed \(stats.totalChunks) chunks from \(stats.totalDocuments) files"
                    isIndexing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Indexing error: \(error.localizedDescription)"
                    isIndexing = false
                }
            }
        }
    }

    /// Index entire directory with all supported files
    func indexDirectory(directoryPath: String, fileExtensions: [String] = ["swift", "md", "txt"]) {
        isIndexing = true
        indexingProgress = "Scanning directory..."
        errorMessage = nil

        Task {
            do {
                let stats = try await vectorSearchService.indexDirectory(
                    at: directoryPath,
                    fileExtensions: fileExtensions
                ) { file, current, total in
                    Task { @MainActor [weak self] in
                        self?.indexingProgress = "Indexing \(current)/\(total): \(file)"
                    }
                }

                await MainActor.run {
                    indexingStatistics = stats
                    indexingProgress = "✅ Indexed \(stats.totalChunks) chunks from \(stats.totalDocuments) files"
                    isIndexing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Indexing error: \(error.localizedDescription)"
                    isIndexing = false
                }
            }
        }
    }

    /// Index specific files
    func indexFiles(_ filePaths: [String]) {
        isIndexing = true
        indexingProgress = "Starting indexing..."
        errorMessage = nil

        Task {
            do {
                let stats = try await vectorSearchService.indexDocuments(
                    at: filePaths
                ) { file, current, total in
                    Task { @MainActor [weak self] in
                        self?.indexingProgress = "Indexing \(current)/\(total): \(file)"
                    }
                }

                await MainActor.run {
                    indexingStatistics = stats
                    indexingProgress = "✅ Indexed \(stats.totalChunks) chunks from \(stats.totalDocuments) files"
                    isIndexing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Indexing error: \(error.localizedDescription)"
                    isIndexing = false
                }
            }
        }
    }

    /// Search in indexed documents
    func searchDocuments(query: String, topK: Int = 5) {
        guard !query.isEmpty else { return }

        isSearching = true
        errorMessage = nil

        Task {
            do {
                let results = try await vectorSearchService.search(query: query, topK: topK)

                await MainActor.run {
                    searchResults = results
                    showingSearchResults = true
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Search error: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }

    /// Ask Claude about search result
    func askAboutSearchResult(_ result: SearchResult) {
        let cleanedContent = result.chunk.content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let prompt = """
        Объясни этот код из файла \(result.chunk.fileName):

        \(cleanedContent)

        Что он делает и как используется?
        """

        currentMessage = prompt
        showingSearchResults = false
    }

    /// Copy search result to clipboard
    func copySearchResult(_ result: SearchResult) {
        let cleanedContent = result.chunk.content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(cleanedContent, forType: .string)
    }

    /// Use search result in message (insert raw text)
    func useSearchResult(_ result: SearchResult) {
        let cleanedContent = result.chunk.content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Limit to reasonable length
        let maxLength = 500
        let displayContent = cleanedContent.count > maxLength
            ? String(cleanedContent.prefix(maxLength)) + "..."
            : cleanedContent

        let context = """
        Found in: \(result.chunk.fileName)
        Relevance: \(String(format: "%.1f%%", result.similarity * 100))

        \(displayContent)
        """

        currentMessage = context
        showingSearchResults = false
    }

    /// Clear vector search index
    func clearSearchIndex() {
        Task {
            do {
                try vectorSearchService.clearIndex()
                await MainActor.run {
                    searchResults = []
                    indexingStatistics = nil
                    indexingProgress = "Index cleared"
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to clear index: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - RAG Comparison

    /// Compare answers with RAG vs without RAG
    func compareRAG(question: String, topK: Int = 5) async throws -> RAGComparisonResult {
        print("🆚 Starting RAG comparison for: \(question)")

        // Initialize RAG service
        let ragService = RAGService(vectorSearchService: vectorSearchService)

        // Run both queries in parallel
        async let ragResponseTask = try ragService.answerWithRAG(question: question, topK: topK)
        async let noRAGResponseTask = try ragService.answerWithoutRAG(question: question)

        // Wait for both
        let (ragResponse, noRAGResponse) = try await (ragResponseTask, noRAGResponseTask)

        let result = RAGComparisonResult(
            question: question,
            withRAG: ragResponse.answer,
            withoutRAG: noRAGResponse.answer,
            usedChunks: ragResponse.usedChunks,
            ragProcessingTime: ragResponse.processingTime,
            noRAGProcessingTime: noRAGResponse.processingTime
        )

        print("✅ RAG comparison complete")
        return result
    }

    /// Answer question using RAG only
    func answerWithRAG(question: String, topK: Int = 5) async throws -> RAGResponse {
        let ragService = RAGService(vectorSearchService: vectorSearchService)
        return try await ragService.answerWithRAG(question: question, topK: topK)
    }

    /// Compare different reranking strategies
    func compareRerankingStrategies(question: String, topK: Int = 5) async throws -> RerankingComparisonResult {
        print("🎯 Starting reranking strategies comparison for: \(question)")

        let ragService = RAGService(vectorSearchService: vectorSearchService)

        // Get search results first (for comparison)
        let searchResults = try await vectorSearchService.search(query: question, topK: 15)

        // Test all strategies
        async let noFilterTask = try ragService.answerWithRAG(
            question: question,
            topK: topK,
            rerankingStrategy: .none
        )

        async let thresholdTask = try ragService.answerWithRAG(
            question: question,
            topK: topK,
            rerankingStrategy: .threshold(0.5)
        )

        async let adaptiveTask = try ragService.answerWithRAG(
            question: question,
            topK: topK,
            rerankingStrategy: .adaptive
        )

        async let llmBasedTask = try ragService.answerWithRAG(
            question: question,
            topK: topK,
            rerankingStrategy: .llmBased
        )

        // Wait for all results
        let (noFilter, threshold, adaptive, llmBased) = try await (
            noFilterTask,
            thresholdTask,
            adaptiveTask,
            llmBasedTask
        )

        let result = RerankingComparisonResult(
            question: question,
            originalResults: searchResults,
            noFilterResults: noFilter,
            thresholdResults: threshold,
            adaptiveResults: adaptive,
            llmResults: llmBased
        )

        print("✅ Reranking comparison complete")
        return result
    }

    /// Test question with mandatory citations
    func testCitationQuestion(question: String) async throws -> (answer: String, validation: CitationValidation, time: TimeInterval) {
        let ragService = RAGService(vectorSearchService: vectorSearchService)
        let startTime = Date()

        let response = try await ragService.answerWithMandatoryCitations(question: question)
        let validation = ragService.validateCitations(response.answer)
        let processingTime = Date().timeIntervalSince(startTime)

        return (response.answer, validation, processingTime)
    }

    // MARK: - RAG Chat with History

    /// Send message using RAG with dialog history
    func sendMessageWithRAG(enableRAG: Bool = true) {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard settings.isConfigured else {
            errorMessage = "API ключ не настроен. Пожалуйста, добавьте его в настройках."
            return
        }

        // Create and save user message
        let userMessage = Message(content: currentMessage, isFromUser: true)
        messages.append(userMessage)
        autoSaveMessage(userMessage)
        autoUpdateConversationTitle()

        let messageToSend = currentMessage
        currentMessage = ""
        isLoading = true
        errorMessage = nil

        Task {
            do {
                if enableRAG {
                    // RAG mode: use document context + history
                    print("🔍 Sending message with RAG + History")

                    let ragService = RAGService(vectorSearchService: vectorSearchService)

                    // Get previous messages as history (exclude current user message)
                    let historyMessages = Array(messages.dropLast())

                    // Get answer with citations
                    let response = try await ragService.answerWithHistory(
                        question: messageToSend,
                        history: historyMessages,
                        topK: 5,
                        rerankingStrategy: .threshold(0.5),
                        maxAttempts: 2
                    )

                    // Extract citations
                    let validation = ragService.validateCitations(response.answer)

                    // Convert SearchResults to RAGSource
                    let ragSources = response.usedChunks.map { searchResult in
                        RAGSource(
                            fileName: searchResult.chunk.fileName,
                            similarity: searchResult.similarity,
                            chunkContent: searchResult.chunk.content
                        )
                    }

                    await MainActor.run {
                        // Create message with RAG metadata
                        let assistantMessage = Message(
                            content: response.answer,
                            isFromUser: false,
                            temperature: self.settings.temperature,
                            metrics: (
                                responseTime: response.processingTime,
                                inputTokens: nil,
                                outputTokens: nil,
                                cost: nil,
                                modelName: "claude-sonnet-4-6"
                            ),
                            usedRAG: true,
                            ragSources: ragSources,
                            citationCount: validation.citationCount
                        )

                        self.messages.append(assistantMessage)
                        self.autoSaveMessage(assistantMessage)
                        self.isLoading = false

                        print("✅ RAG message sent. Citations: \(validation.citationCount), Sources: \(ragSources.count)")
                    }
                } else {
                    // Normal mode: send to Claude directly
                    print("💬 Sending message without RAG (normal mode)")
                    await MainActor.run {
                        self.sendToClaudeDirectly(message: messageToSend)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Ошибка RAG: \(error.localizedDescription)"
                    print("❌ RAG Error: \(error)")
                }
            }
        }
    }

    // MARK: - Voice Input

    /// Start voice input (recording and recognition)
    func startVoiceInput() async {
        print("🎤 Starting voice input...")

        // Request authorization first
        let authorized = await speechRecognitionService.requestAuthorization()

        guard authorized else {
            await MainActor.run {
                self.errorMessage = "Нет разрешения на использование микрофона или распознавания речи"
            }
            print("❌ Voice input not authorized")
            return
        }

        // Start recording
        do {
            try speechRecognitionService.startRecording()

            await MainActor.run {
                self.isListening = true
                self.voiceInputText = ""
                self.errorMessage = nil
            }

            print("✅ Voice input started")
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка запуска записи: \(error.localizedDescription)"
                self.isListening = false
            }
            print("❌ Voice input error: \(error)")
        }
    }

    /// Stop voice input and send to LLM
    func stopVoiceInputAndSend() {
        print("⏹ Stopping voice input and sending...")

        // Stop recording
        speechRecognitionService.stopRecording()

        // Wait a bit for final recognition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Get recognized text
            let recognizedText = self.speechRecognitionService.recognizedText

            // Set as current message
            self.currentMessage = recognizedText

            // Update state
            self.isListening = false
            self.voiceInputText = ""

            // Send to LLM if text is not empty
            if !recognizedText.isEmpty {
                print("📤 Sending recognized text: \(recognizedText)")
                self.sendMessage()
            } else {
                self.errorMessage = "Не удалось распознать речь. Попробуйте ещё раз."
                print("⚠️ No text recognized")
            }
        }
    }

    /// Cancel voice input without sending
    func cancelVoiceInput() {
        print("❌ Cancelling voice input...")

        speechRecognitionService.cancelRecording()

        isListening = false
        voiceInputText = ""

        print("✅ Voice input cancelled")
    }

    /// Toggle voice input (start/stop)
    func toggleVoiceInput() {
        if isListening {
            stopVoiceInputAndSend()
        } else {
            Task {
                await startVoiceInput()
            }
        }
    }
}

