//
//  MultiAgentService.swift
//  AIAdventChatV2
//
//  Created by Claude on 10.10.2025.
//

import Foundation

// MARK: - Data Models

struct AgentPlan: Codable {
    let task_understanding: String
    let steps: [String]
    let expected_output: String
    let considerations: [String]
}

struct AgentImplementation: Codable {
    let solution: String
    let code: String?
    let explanation: String
    let test_cases: [String]?
}

struct MultiAgentResult {
    let plannerResponse: String
    let plannerPlan: AgentPlan?
    let implementerResponse: String
    let implementation: AgentImplementation?
    let totalTime: TimeInterval
    let plannerMetrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?)
    let implementerMetrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?)
}

// MARK: - Multi-Agent Service

class MultiAgentService {

    private let apiKey: String
    private let temperature: Double

    init(apiKey: String, temperature: Double = 0.7) {
        self.apiKey = apiKey
        self.temperature = temperature
    }

    // MARK: - Main Method

    func executeMultiAgentTask(
        userTask: String,
        completion: @escaping (Result<MultiAgentResult, Error>) -> Void
    ) {
        let startTime = Date()

        // Шаг 1: Агент-планировщик создает план
        executePlannerAgent(task: userTask) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let plannerData):
                // Шаг 2: Агент-реализатор выполняет план
                self.executeImplementerAgent(
                    task: userTask,
                    plan: plannerData.response,
                    parsedPlan: plannerData.plan
                ) { implementerResult in
                    switch implementerResult {
                    case .success(let implementerData):
                        let totalTime = Date().timeIntervalSince(startTime)

                        let result = MultiAgentResult(
                            plannerResponse: plannerData.response,
                            plannerPlan: plannerData.plan,
                            implementerResponse: implementerData.response,
                            implementation: implementerData.implementation,
                            totalTime: totalTime,
                            plannerMetrics: plannerData.metrics,
                            implementerMetrics: implementerData.metrics
                        )
                        completion(.success(result))

                    case .failure(let error):
                        completion(.failure(error))
                    }
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Agent 1: Planner

    private func executePlannerAgent(
        task: String,
        completion: @escaping (Result<(response: String, plan: AgentPlan?, metrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?)), Error>) -> Void
    ) {
        let startTime = Date()

        let systemPrompt = """
        Вы - агент-планировщик. Ваша задача - анализировать задачи пользователя и создавать детальный план действий.

        ВСЕГДА отвечайте в формате JSON со следующей структурой:
        {
            "task_understanding": "Краткое описание того, как вы поняли задачу",
            "steps": [
                "Шаг 1: Описание",
                "Шаг 2: Описание",
                "Шаг 3: Описание"
            ],
            "expected_output": "Описание ожидаемого результата",
            "considerations": [
                "Важный момент 1",
                "Важный момент 2"
            ]
        }

        Будьте конкретны и структурированы. Думайте о том, что агент-реализатор будет использовать ваш план для выполнения работы.
        """

        let userMessage = """
        Проанализируй следующую задачу и создай детальный план:

        \(task)
        """

        sendClaudeRequest(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.3, // Низкая температура для точности планирования
            startTime: startTime
        ) { result in
            switch result {
            case .success(let data):
                // Пытаемся распарсить план
                let plan = self.parsePlan(from: data.text)
                completion(.success((
                    response: data.text,
                    plan: plan,
                    metrics: data.metrics
                )))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Agent 2: Implementer

    private func executeImplementerAgent(
        task: String,
        plan: String,
        parsedPlan: AgentPlan?,
        completion: @escaping (Result<(response: String, implementation: AgentImplementation?, metrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?)), Error>) -> Void
    ) {
        let startTime = Date()

        let systemPrompt = """
        Вы - агент-реализатор. Ваша задача - выполнять задачи на основе плана от агента-планировщика.

        ВСЕГДА отвечайте в формате JSON со следующей структурой:
        {
            "solution": "Подробное описание решения",
            "code": "Код (если требуется), или null",
            "explanation": "Пошаговое объяснение реализации",
            "test_cases": [
                "Тест-кейс 1",
                "Тест-кейс 2"
            ]
        }

        Следуйте плану и реализуйте каждый шаг. Будьте практичны и давайте работающее решение.
        """

        let userMessage = """
        ИСХОДНАЯ ЗАДАЧА:
        \(task)

        ПЛАН ОТ АГЕНТА-ПЛАНИРОВЩИКА:
        \(plan)

        Теперь реализуй эту задачу, следуя плану. Дай конкретное решение.
        """

        sendClaudeRequest(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.7, // Умеренная температура для креативности в решении
            startTime: startTime
        ) { result in
            switch result {
            case .success(let data):
                // Пытаемся распарсить реализацию
                let implementation = self.parseImplementation(from: data.text)
                completion(.success((
                    response: data.text,
                    implementation: implementation,
                    metrics: data.metrics
                )))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Claude API Request

    private func sendClaudeRequest(
        systemPrompt: String,
        userMessage: String,
        temperature: Double,
        startTime: Date,
        completion: @escaping (Result<(text: String, metrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?)), Error>) -> Void
    ) {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            completion(.failure(NSError(domain: "MultiAgentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 60.0

        let requestBody: [String: Any] = [
            "model": "claude-3-7-sonnet-20250219",
            "max_tokens": 2000,
            "temperature": temperature,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": userMessage
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            let responseTime = Date().timeIntervalSince(startTime)

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "MultiAgentService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Нет данных"])))
                return
            }

            // Проверка HTTP статуса
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    completion(.failure(NSError(domain: "MultiAgentService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"])))
                    return
                }
            }

            // Парсим ответ
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {

                    // Извлекаем метрики
                    var inputTokens: Int?
                    var outputTokens: Int?
                    var cost: Double?

                    if let usage = json["usage"] as? [String: Any] {
                        inputTokens = usage["input_tokens"] as? Int
                        outputTokens = usage["output_tokens"] as? Int

                        if let input = inputTokens, let output = outputTokens {
                            let inputCost = Double(input) * 0.000003
                            let outputCost = Double(output) * 0.000015
                            cost = inputCost + outputCost
                        }
                    }

                    completion(.success((
                        text: text,
                        metrics: (
                            responseTime: responseTime,
                            inputTokens: inputTokens,
                            outputTokens: outputTokens,
                            cost: cost
                        )
                    )))
                } else {
                    completion(.failure(NSError(domain: "MultiAgentService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Не удалось распарсить ответ"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Parsing Helpers

    private func parsePlan(from text: String) -> AgentPlan? {
        guard let jsonData = text.data(using: .utf8) else { return nil }

        // Пытаемся найти JSON в тексте
        if let plan = try? JSONDecoder().decode(AgentPlan.self, from: jsonData) {
            return plan
        }

        // Если не получилось, ищем JSON блок
        if let jsonStart = text.firstIndex(of: "{"),
           let jsonEnd = text.lastIndex(of: "}") {
            let jsonString = String(text[jsonStart...jsonEnd])
            if let jsonData = jsonString.data(using: .utf8),
               let plan = try? JSONDecoder().decode(AgentPlan.self, from: jsonData) {
                return plan
            }
        }

        return nil
    }

    private func parseImplementation(from text: String) -> AgentImplementation? {
        guard let jsonData = text.data(using: .utf8) else { return nil }

        // Пытаемся найти JSON в тексте
        if let implementation = try? JSONDecoder().decode(AgentImplementation.self, from: jsonData) {
            return implementation
        }

        // Если не получилось, ищем JSON блок
        if let jsonStart = text.firstIndex(of: "{"),
           let jsonEnd = text.lastIndex(of: "}") {
            let jsonString = String(text[jsonStart...jsonEnd])
            if let jsonData = jsonString.data(using: .utf8),
               let implementation = try? JSONDecoder().decode(AgentImplementation.self, from: jsonData) {
                return implementation
            }
        }

        return nil
    }
}
