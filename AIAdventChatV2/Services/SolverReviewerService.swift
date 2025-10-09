//
//  SolverReviewerService.swift
//  AIAdventChatV2
//
//  Created by Claude on 10.10.2025.
//

import Foundation

// MARK: - Data Models

struct AgentSolution: Codable {
    let solution: String
    let code: String?
    let explanation: String
    let approach: String
}

struct AgentReview: Codable {
    let verdict: String // "correct", "incorrect", "partially_correct"
    let strengths: [String]
    let weaknesses: [String]
    let errors_found: [String]?
    let suggestions: [String]
    let corrected_solution: String?
    let overall_assessment: String
}

struct SolverReviewerResult {
    let solverResponse: String
    let solution: AgentSolution?
    let reviewerResponse: String
    let review: AgentReview?
    let totalTime: TimeInterval
    let solverMetrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?)
    let reviewerMetrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?)
}

// MARK: - Solver-Reviewer Service

class SolverReviewerService {

    private let apiKey: String
    private let temperature: Double

    init(apiKey: String, temperature: Double = 0.7) {
        self.apiKey = apiKey
        self.temperature = temperature
    }

    // MARK: - Main Method

    func executeSolverReviewerTask(
        userTask: String,
        completion: @escaping (Result<SolverReviewerResult, Error>) -> Void
    ) {
        let startTime = Date()

        // Шаг 1: Агент-решатель решает задачу
        executeSolverAgent(task: userTask) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let solverData):
                // Шаг 2: Агент-проверяющий проверяет решение
                self.executeReviewerAgent(
                    task: userTask,
                    solution: solverData.response,
                    parsedSolution: solverData.solution
                ) { reviewerResult in
                    switch reviewerResult {
                    case .success(let reviewerData):
                        let totalTime = Date().timeIntervalSince(startTime)

                        let result = SolverReviewerResult(
                            solverResponse: solverData.response,
                            solution: solverData.solution,
                            reviewerResponse: reviewerData.response,
                            review: reviewerData.review,
                            totalTime: totalTime,
                            solverMetrics: solverData.metrics,
                            reviewerMetrics: reviewerData.metrics
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

    // MARK: - Agent 1: Solver

    private func executeSolverAgent(
        task: String,
        completion: @escaping (Result<(response: String, solution: AgentSolution?, metrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?)), Error>) -> Void
    ) {
        let startTime = Date()

        let systemPrompt = """
        Вы - агент-решатель. Ваша задача - решать задачи любого типа: математические, логические, программирование, и т.д.

        ВСЕГДА отвечайте в формате JSON со следующей структурой:
        {
            "solution": "Финальный ответ/решение задачи",
            "code": "Код, если задача требует программирования, или null",
            "explanation": "Подробное пошаговое объяснение решения",
            "approach": "Какой подход вы использовали для решения"
        }

        Будьте внимательны к деталям. Ваше решение будет проверено другим агентом.

        Примеры задач:
        - Математика: "Реши уравнение 2x + 6 = 14"
        - Логика: "У фермера 17 овец. Все, кроме 9, умерли. Сколько осталось?"
        - Программирование: "Напиши функцию для сортировки массива"
        - Задачи на смекалку: "Как разделить 100 монет между 3 людьми поровну?"
        """

        let userMessage = """
        Реши следующую задачу:

        \(task)

        Дай полное решение с объяснением.
        """

        sendClaudeRequest(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.5, // Средняя температура для баланса точности и креативности
            startTime: startTime
        ) { result in
            switch result {
            case .success(let data):
                // Пытаемся распарсить решение
                let solution = self.parseSolution(from: data.text)
                completion(.success((
                    response: data.text,
                    solution: solution,
                    metrics: data.metrics
                )))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Agent 2: Reviewer

    private func executeReviewerAgent(
        task: String,
        solution: String,
        parsedSolution: AgentSolution?,
        completion: @escaping (Result<(response: String, review: AgentReview?, metrics: (responseTime: TimeInterval, inputTokens: Int?, outputTokens: Int?, cost: Double?)), Error>) -> Void
    ) {
        let startTime = Date()

        let systemPrompt = """
        Вы - агент-проверяющий. Ваша задача - критически оценивать решения других агентов.

        ВСЕГДА отвечайте в формате JSON со следующей структурой:
        {
            "verdict": "correct/incorrect/partially_correct",
            "strengths": [
                "Сильная сторона 1",
                "Сильная сторона 2"
            ],
            "weaknesses": [
                "Слабая сторона 1",
                "Слабая сторона 2"
            ],
            "errors_found": [
                "Ошибка 1 (если есть)",
                "Ошибка 2 (если есть)"
            ],
            "suggestions": [
                "Предложение по улучшению 1",
                "Предложение по улучшению 2"
            ],
            "corrected_solution": "Исправленное решение, если нашли ошибки, или null",
            "overall_assessment": "Общая оценка качества решения"
        }

        Будьте строгим но справедливым критиком. Проверяйте:
        - Правильность решения
        - Логику рассуждений
        - Полноту объяснения
        - Оптимальность подхода
        - Наличие ошибок в коде (если есть)
        """

        let userMessage = """
        ИСХОДНАЯ ЗАДАЧА:
        \(task)

        РЕШЕНИЕ ОТ АГЕНТА-РЕШАТЕЛЯ:
        \(solution)

        Проверь это решение. Найди ошибки (если есть), оцени подход, дай рекомендации.
        """

        sendClaudeRequest(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.3, // Низкая температура для строгой проверки
            startTime: startTime
        ) { result in
            switch result {
            case .success(let data):
                // Пытаемся распарсить проверку
                let review = self.parseReview(from: data.text)
                completion(.success((
                    response: data.text,
                    review: review,
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
            completion(.failure(NSError(domain: "SolverReviewerService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])))
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
                completion(.failure(NSError(domain: "SolverReviewerService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Нет данных"])))
                return
            }

            // Проверка HTTP статуса
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    completion(.failure(NSError(domain: "SolverReviewerService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"])))
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
                    completion(.failure(NSError(domain: "SolverReviewerService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Не удалось распарсить ответ"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Parsing Helpers

    private func parseSolution(from text: String) -> AgentSolution? {
        guard let jsonData = text.data(using: .utf8) else { return nil }

        // Пытаемся найти JSON в тексте
        if let solution = try? JSONDecoder().decode(AgentSolution.self, from: jsonData) {
            return solution
        }

        // Если не получилось, ищем JSON блок
        if let jsonStart = text.firstIndex(of: "{"),
           let jsonEnd = text.lastIndex(of: "}") {
            let jsonString = String(text[jsonStart...jsonEnd])
            if let jsonData = jsonString.data(using: .utf8),
               let solution = try? JSONDecoder().decode(AgentSolution.self, from: jsonData) {
                return solution
            }
        }

        return nil
    }

    private func parseReview(from text: String) -> AgentReview? {
        guard let jsonData = text.data(using: .utf8) else { return nil }

        // Пытаемся найти JSON в тексте
        if let review = try? JSONDecoder().decode(AgentReview.self, from: jsonData) {
            return review
        }

        // Если не получилось, ищем JSON блок
        if let jsonStart = text.firstIndex(of: "{"),
           let jsonEnd = text.lastIndex(of: "}") {
            let jsonString = String(text[jsonStart...jsonEnd])
            if let jsonData = jsonString.data(using: .utf8),
               let review = try? JSONDecoder().decode(AgentReview.self, from: jsonData) {
                return review
            }
        }

        return nil
    }
}
