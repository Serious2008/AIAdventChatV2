//
//  ChatViewModel.swift
//  AIAdventChatV2
//
//  Created by Sergey Markov on 01.10.2025.
//

import Foundation
import Combine

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

    internal let settings: Settings
    private var cancellables = Set<AnyCancellable>()
    private let huggingFaceService = HuggingFaceService()
    private let claudeService = ClaudeService()
    private let localModelService = LocalModelService()
    private let yandexTrackerService = YandexTrackerService()
    private let periodicTaskService = PeriodicTaskService()
    private let simulatorService = SimulatorService()

    init(settings: Settings) {
        self.settings = settings
        periodicTaskService.chatViewModel = self
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
            content: "🔄 Суммаризация текста с помощью Claude (claude-3-7-sonnet-20250219)...",
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
                            content: "✅ Текст суммаризирован (сжатие: \(compressionRatio)%) • Модель: claude-3-7-sonnet-20250219",
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

            systemPrompt = """
                Вы - \(capabilitiesText).
                \(toolsDescription)

                Для обычных вопросов отвечайте как обычный ассистент.
                Используйте естественный язык для всех ответов.
                """

            print("📋 System Prompt:")
            print(systemPrompt)
        }

        // Формируем историю сообщений для контекста
        var messagesArray: [[String: String]] = []

        // Включаем историю сообщений (исключая системные сообщения)
        for msg in messages {
            // Пропускаем системные сообщения (индикаторы прогресса и т.д.)
            if msg.isSystemMessage == true {
                continue
            }

            messagesArray.append([
                "role": msg.isFromUser ? "user" : "assistant",
                "content": msg.content
            ])
        }

        // Добавляем текущее сообщение
        messagesArray.append([
            "role": "user",
            "content": message
        ])

        print("📨 Отправляем \(messagesArray.count) сообщений в историю (включая текущее)")

        // Добавляем инструменты если Yandex Tracker настроен
        var requestBody: [String: Any] = [
            "model": "claude-3-7-sonnet-20250219",
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
                                        modelName: "claude-3-7-sonnet-20250219"
                                    )
                                )
                                messages.append(claudeMessage)
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
                                    modelName: "claude-3-7-sonnet-20250219"
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
                    modelName: "claude-3-7-sonnet-20250219"
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
                modelName: "claude-3-7-sonnet-20250219"
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
            "model": "claude-3-7-sonnet-20250219",
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
                            modelName: "claude-3-7-sonnet-20250219"
                        )
                    )
                    messages.append(claudeMessage)
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
                                    modelName: "claude-3-7-sonnet-20250219"
                                )
                            )
                            messages.append(claudeMessage)
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
}

