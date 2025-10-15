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
            let hasTrackerTools = settings.isYandexTrackerConfigured && yandexTrackerService.isConnected
            let hasPeriodicTasks = true // Периодические задачи всегда доступны

            if hasTrackerTools && hasPeriodicTasks {
                systemPrompt = """
                    Вы - полезный ассистент с доступом к инструментам Yandex Tracker и периодическим задачам.

                    Когда пользователь спрашивает о задачах, статистике или других данных из Yandex Tracker, используйте доступные инструменты для получения актуальной информации.

                    Когда пользователь просит периодически присылать информацию (например: "Пиши мне погоду каждый час"), используйте инструменты для создания автоматических периодических задач.

                    Для обычных вопросов отвечайте как обычный ассистент.
                    Используйте естественный язык для всех ответов.
                    """
            } else if hasTrackerTools {
                systemPrompt = """
                    Вы - полезный ассистент с доступом к инструментам Yandex Tracker.

                    Когда пользователь спрашивает о задачах, статистике или других данных из Yandex Tracker, используйте доступные инструменты для получения актуальной информации.

                    Для обычных вопросов отвечайте как обычный ассистент.
                    Используйте естественный язык для всех ответов.
                    """
            } else if hasPeriodicTasks {
                systemPrompt = """
                    Вы - полезный ассистент с возможностью создания автоматических периодических задач.

                    Когда пользователь просит периодически присылать информацию (например: "Пиши мне погоду каждый час", "Присылай обновления погоды раз в час"), используйте доступные инструменты для создания автоматических задач.

                    Для обычных вопросов отвечайте как обычный ассистент.
                    Используйте естественный язык для всех ответов.
                    """
            } else {
                systemPrompt = """
                    Вы - полезный ассистент.

                    Отвечайте на вопросы пользователя естественным языком.
                    Будьте дружелюбны и полезны.
                    """
            }
        }

        // Формируем историю сообщений для контекста
        var messagesArray: [[String: String]] = []
        if conversationMode == .collectingRequirements {
            // Включаем всю историю диалога для сбора ТЗ (и вопросы Claude, и ответы пользователя)
            for msg in messages {
                messagesArray.append([
                    "role": msg.isFromUser ? "user" : "assistant",
                    "content": msg.content
                ])
            }
        }
        // Добавляем текущее сообщение
        messagesArray.append([
            "role": "user",
            "content": message
        ])

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

        // Инструменты Yandex Tracker если настроены
        if settings.isYandexTrackerConfigured && yandexTrackerService.isConnected {
            allTools.append(contentsOf: YandexTrackerToolsProvider.getTools())
        }

        // Инструменты периодических задач (всегда доступны)
        allTools.append(contentsOf: PeriodicTaskToolsProvider.getTools())

        // Формируем JSON для tools если есть хотя бы один инструмент
        if !allTools.isEmpty {
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
                self?.isLoading = false

                if let error = error {
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
                        self?.handleError("Неверный API ключ. Проверьте настройки.")
                        return
                    } else if httpResponse.statusCode >= 400 {
                        self?.handleError("Ошибка сервера: \(httpResponse.statusCode)")
                        return
                    }
                }

                guard let data = data else {
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
                        // Обрабатываем tool use
                        Task {
                            await handleToolUse(content: content, responseTime: responseTime, inputTokens: inputTokens, outputTokens: outputTokens, cost: cost, originalMessage: originalMessage)
                        }
                    } else {
                        // Обычный текстовый ответ
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
                    
                    handleError("Неожиданный формат ответа. Проверьте консоль для отладочной информации.")
                }
            }
        } catch {
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
                        // Yandex Tracker инструмент
                        result = try await YandexTrackerToolsProvider.executeTool(
                            name: toolName,
                            input: toolInput,
                            trackerService: yandexTrackerService
                        )
                    } else if toolName.contains("weather") || toolName.contains("task") {
                        // Periodic Task инструмент
                        result = PeriodicTaskToolsProvider.executeTool(
                            name: toolName,
                            input: toolInput,
                            periodicTaskService: periodicTaskService
                        )
                    } else {
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
                self?.isLoading = false

                if let error = error {
                    print("❌ Ошибка сети при отправке результатов инструментов: \(error.localizedDescription)")
                    self?.handleError("Ошибка сети: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
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
}

