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

    // Разбиение текста на чанки с учетом размера контекстного окна
    private func splitIntoChunks(_ text: String, maxChunkSize: Int = 6000) -> [String] {
        // Разбиваем текст на предложения для лучшего качества
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        var chunks: [String] = []
        var currentChunk = ""

        for sentence in sentences {
            let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedSentence.isEmpty { continue }

            let sentenceWithPunctuation = trimmedSentence + "."

            // Если добавление предложения превысит размер чанка
            if (currentChunk.count + sentenceWithPunctuation.count) > maxChunkSize {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentChunk = ""
                }

                // Если само предложение больше maxChunkSize, делим его
                if sentenceWithPunctuation.count > maxChunkSize {
                    let words = sentenceWithPunctuation.components(separatedBy: " ")
                    var wordChunk = ""
                    for word in words {
                        if (wordChunk.count + word.count + 1) > maxChunkSize {
                            if !wordChunk.isEmpty {
                                chunks.append(wordChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                            wordChunk = word + " "
                        } else {
                            wordChunk += word + " "
                        }
                    }
                    if !wordChunk.isEmpty {
                        currentChunk = wordChunk
                    }
                } else {
                    currentChunk = sentenceWithPunctuation + " "
                }
            } else {
                currentChunk += sentenceWithPunctuation + " "
            }
        }

        // Добавляем последний чанк
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return chunks
    }

    // Метод для суммаризации текста перед отправкой в Claude (с поддержкой Sequential Chunking)
    func summarize(
        text: String,
        apiKey: String,
        progressCallback: ((String) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Максимальный размер чанка (примерно 1500 токенов = 6000 символов)
        let maxChunkSize = 6000

        // Если текст помещается в один чанк, суммаризируем напрямую
        if text.count <= maxChunkSize {
            summarizeChunk(
                chunk: text,
                apiKey: apiKey,
                isFirstChunk: true,
                isLastChunk: true,
                isFinalSummary: false,
                completion: completion
            )
            return
        }

        // Разбиваем текст на чанки
        let chunks = splitIntoChunks(text, maxChunkSize: maxChunkSize)
        print("📦 Текст разбит на \(chunks.count) чанков для суммаризации")
        progressCallback?("Разбито на \(chunks.count) чанков")

        // Последовательная суммаризация чанков
        summarizeChunksSequentially(chunks: chunks, apiKey: apiKey, progressCallback: progressCallback, completion: completion)
    }

    // Последовательная суммаризация чанков
    private func summarizeChunksSequentially(
        chunks: [String],
        apiKey: String,
        progressCallback: ((String) -> Void)?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var summarizedChunks: [String] = []
        var currentIndex = 0

        func summarizeNextChunk() {
            guard currentIndex < chunks.count else {
                // Все чанки суммаризированы, объединяем результаты
                let combinedSummary = summarizedChunks.joined(separator: " ")

                // Если результат все еще слишком длинный, делаем финальную суммаризацию
                if combinedSummary.count > 6000 {
                    print("📝 Финальная суммаризация объединенного результата")
                    progressCallback?("Финальная суммаризация")
                    summarizeChunk(
                        chunk: combinedSummary,
                        apiKey: apiKey,
                        isFirstChunk: true,
                        isLastChunk: true,
                        isFinalSummary: true,
                        completion: completion
                    )
                } else {
                    completion(.success(combinedSummary))
                }
                return
            }

            let chunk = chunks[currentIndex]
            let isFirstChunk = (currentIndex == 0)
            let isLastChunk = (currentIndex == chunks.count - 1)

            print("📄 Суммаризация чанка \(currentIndex + 1)/\(chunks.count)")
            progressCallback?("Чанк \(currentIndex + 1)/\(chunks.count)")

            summarizeChunk(
                chunk: chunk,
                apiKey: apiKey,
                isFirstChunk: isFirstChunk,
                isLastChunk: isLastChunk,
                isFinalSummary: false
            ) { result in
                switch result {
                case .success(let summary):
                    summarizedChunks.append(summary)
                    currentIndex += 1
                    summarizeNextChunk()
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }

        summarizeNextChunk()
    }

    // Метод для суммаризации одного чанка текста
    private func summarizeChunk(
        chunk: String,
        apiKey: String,
        isFirstChunk: Bool,
        isLastChunk: Bool,
        isFinalSummary: Bool,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Используем легкую модель для суммаризации
        let summarizationModel = "katanemo/Arch-Router-1.5B"

        guard let url = URL(string: "https://router.huggingface.co/v1/chat/completions") else {
            completion(.failure(NSError(domain: "HuggingFaceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0

        let summarizationPrompt: String
        if isFinalSummary {
            summarizationPrompt = """
            Create a final comprehensive summary by combining the following partial summaries.
            Keep all important information and write in the same language as the original text:

            \(chunk)
            """
        } else {
            summarizationPrompt = """
            Summarize the following text concisely, keeping the main points and key information.
            Keep it brief but informative. Write in the same language as the original text:

            \(chunk)
            """
        }

        let requestBody: [String: Any] = [
            "model": summarizationModel,
            "messages": [
                [
                    "role": "user",
                    "content": summarizationPrompt
                ]
            ],
            "temperature": 0.3,
            "max_tokens": 300
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
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
                if httpResponse.statusCode >= 400 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        completion(.failure(NSError(domain: "HuggingFaceService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ошибка суммаризации (\(httpResponse.statusCode)): \(responseString)"])))
                    } else {
                        completion(.failure(NSError(domain: "HuggingFaceService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ошибка суммаризации: \(httpResponse.statusCode)"])))
                    }
                    return
                }
            }

            // Парсим ответ
            do {
                let chatResponse = try JSONDecoder().decode(HuggingFaceChatResponse.self, from: data)

                if let firstChoice = chatResponse.choices.first {
                    let summarizedText = firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(.success(summarizedText))
                    return
                }

                completion(.failure(NSError(domain: "HuggingFaceService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Пустой ответ при суммаризации"])))
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    completion(.failure(NSError(domain: "HuggingFaceService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Ошибка парсинга суммаризации: \(error.localizedDescription)\nОтвет: \(responseString)"])))
                } else {
                    completion(.failure(NSError(domain: "HuggingFaceService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Не удалось распарсить ответ суммаризации: \(error.localizedDescription)"])))
                }
            }
        }.resume()
    }
}
