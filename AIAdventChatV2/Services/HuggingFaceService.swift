//
//  HuggingFaceService.swift
//  AIAdventChatV2
//
//  Created by Claude on 01.10.2025.
//

import Foundation

// Response format for new chat completions API
struct HuggingFaceChatResponse: Codable {
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable {
        let message: Message

        struct Message: Codable {
            let content: String
        }
    }

    struct Usage: Codable {
        let prompt_tokens: Int?
        let completion_tokens: Int?
        let total_tokens: Int?
    }
}

struct ModelMetrics {
    let responseTime: TimeInterval
    let inputTokens: Int?
    let outputTokens: Int?
    let totalCost: Double?
    let modelName: String
}

class HuggingFaceService {

    // Модели, доступные через новый Inference Providers API
    static let availableModels = [
        // Маленькие модели
        "katanemo/Arch-Router-1.5B",
        "microsoft/phi-2",

        // Средние модели
        "meta-llama/Llama-3.1-8B-Instruct",
        "mistralai/Mistral-7B-Instruct-v0.3",

        // Большие модели
        "deepseek-ai/DeepSeek-V3-0324",
        "Qwen/Qwen2.5-72B-Instruct"
    ]

    func sendRequest(
        model: String,
        message: String,
        apiKey: String,
        temperature: Double,
        completion: @escaping (Result<(String, ModelMetrics), Error>) -> Void
    ) {
        let startTime = Date()

        guard let url = URL(string: "https://router.huggingface.co/v1/chat/completions") else {
            completion(.failure(NSError(domain: "HuggingFaceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60.0

        // Новый формат запроса - chat completions (как OpenAI)
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": message
                ]
            ],
            "temperature": min(temperature, 1.0),
            "max_tokens": 500
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
                completion(.failure(NSError(domain: "HuggingFaceService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Нет данных"])))
                return
            }

            // Проверяем HTTP статус
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HuggingFace HTTP Status: \(httpResponse.statusCode)")
                print("📊 Request URL: \(httpResponse.url?.absoluteString ?? "unknown")")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📊 Response Body: \(responseString)")
                }

                if httpResponse.statusCode == 503 {
                    completion(.failure(NSError(domain: "HuggingFaceService", code: -6, userInfo: [NSLocalizedDescriptionKey: "Модель загружается. Попробуйте через 30 секунд."])))
                    return
                }

                if httpResponse.statusCode == 404 {
                    completion(.failure(NSError(domain: "HuggingFaceService", code: -7, userInfo: [NSLocalizedDescriptionKey: "Модель не найдена или недоступна через Inference API."])))
                    return
                }

                if httpResponse.statusCode == 403 {
                    completion(.failure(NSError(domain: "HuggingFaceService", code: -8, userInfo: [NSLocalizedDescriptionKey: "Доступ запрещен. Проверьте API ключ или модель требует доступа."])))
                    return
                }

                if httpResponse.statusCode >= 400 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        completion(.failure(NSError(domain: "HuggingFaceService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ошибка API (\(httpResponse.statusCode)): \(responseString)"])))
                    } else {
                        completion(.failure(NSError(domain: "HuggingFaceService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ошибка API: \(httpResponse.statusCode)"])))
                    }
                    return
                }
            }

            // Парсим новый формат ответа (chat completions)
            do {
                let chatResponse = try JSONDecoder().decode(HuggingFaceChatResponse.self, from: data)

                if let firstChoice = chatResponse.choices.first {
                    let text = firstChoice.message.content

                    let metrics = ModelMetrics(
                        responseTime: responseTime,
                        inputTokens: chatResponse.usage?.prompt_tokens ?? self.estimateTokens(message),
                        outputTokens: chatResponse.usage?.completion_tokens ?? self.estimateTokens(text),
                        totalCost: 0.0,
                        modelName: model
                    )
                    completion(.success((text, metrics)))
                    return
                }

                completion(.failure(NSError(domain: "HuggingFaceService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Пустой ответ от модели"])))
            } catch {
                // Если не удалось распарсить, выводим ошибку
                if let responseString = String(data: data, encoding: .utf8) {
                    completion(.failure(NSError(domain: "HuggingFaceService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Ошибка парсинга: \(error.localizedDescription)\nОтвет: \(responseString)"])))
                } else {
                    completion(.failure(NSError(domain: "HuggingFaceService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Не удалось распарсить ответ: \(error.localizedDescription)"])))
                }
            }
        }.resume()
    }

    // Простая оценка количества токенов (примерно 4 символа = 1 токен)
    private func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }
}
