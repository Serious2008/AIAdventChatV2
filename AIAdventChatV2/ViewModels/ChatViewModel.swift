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

    private let settings: Settings
    private var cancellables = Set<AnyCancellable>()
    private let huggingFaceService = HuggingFaceService()

    init(settings: Settings) {
        self.settings = settings
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

        // Выбираем провайдера
        switch settings.selectedProvider {
        case .claude:
            sendToClaude(message: messageToSend)
        case .huggingface:
            sendToHuggingFace(message: messageToSend)
        }
    }

    private func sendToHuggingFace(message: String) {
        let startTime = Date()

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
            // Если включена суммаризация и есть HuggingFace API ключ
            if !settings.huggingFaceApiKey.isEmpty {
                // Проверяем длину текста
                if message.count < settings.summarizationMinLength {
                    // Текст слишком короткий, пропускаем суммаризацию
                    print("⏭️ Текст слишком короткий (\(message.count) символов), минимум: \(settings.summarizationMinLength)")
                    loadingMessage = "Claude печатает..."
                    sendToClaudeDirectly(message: message)
                    return
                }

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
                return
            }
        }

        // Если суммаризация не включена или нет ключа, отправляем напрямую
        sendToClaudeDirectly(message: message)
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
        request.timeoutInterval = 30.0 // Увеличиваем таймаут
        
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
            systemPrompt = """
                Вы - полезный ассистент. ВСЕГДА отвечайте в формате JSON.

                Обязательно используйте следующий формат для всех ответов:
                {
                    "response": "ваш ответ здесь",
                    "confidence": "высокая/средняя/низкая",
                    "additional_info": "дополнительная информация при необходимости"
                }

                Не добавляйте никакой текст до или после JSON. Только чистый JSON объект.
                """
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

        let requestBody: [String: Any] = [
            "model": "claude-3-7-sonnet-20250219",
            "max_tokens": 2000,
            "temperature": settings.temperature,
            "system": systemPrompt,
            "messages": messagesArray
        ]
        
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

                self?.processClaudeResponse(data: data, responseTime: responseTime)
            }
        }.resume()
    }
    
    private func processClaudeResponse(data: Data, responseTime: TimeInterval) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {

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

                    // Если в режиме сбора требований, проверяем JSON ответ
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
                } else if let error = json["error"] as? [String: Any],
                          let message = error["message"] as? String {
                    handleError("Ошибка API: \(message)")
                } else {
                    handleError("Неожиданный формат ответа")
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
    
    private func handleError(_ message: String) {
        errorMessage = message
        isLoading = false
    }
    
    func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }
}

