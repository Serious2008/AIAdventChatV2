//
//  ClaudeService.swift
//  AIAdventChatV2
//
//  Created by Claude on 01.10.2025.
//

import Foundation

struct ClaudeResponse: Codable {
    let content: [Content]
    let usage: Usage?
    let model: String?

    struct Content: Codable {
        let text: String
        let type: String
    }

    struct Usage: Codable {
        let input_tokens: Int
        let output_tokens: Int
    }
}

class ClaudeService {
    // Rate limiting: 20000 токенов в минуту
    private let maxTokensPerMinute = 20000
    private var tokensUsedInCurrentMinute = 0
    private var minuteStartTime = Date()
    private let rateLimitQueue = DispatchQueue(label: "com.claudeservice.ratelimit")

    // Очередь для запросов
    private var requestQueue: [(chunk: String, apiKey: String, isFirst: Bool, isLast: Bool, isFinal: Bool, completion: (Result<String, Error>) -> Void)] = []
    private var isProcessingQueue = false

    // Метод для суммаризации текста с использованием Claude
    func summarize(
        text: String,
        apiKey: String,
        progressCallback: ((String) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Максимальный размер чанка для Claude
        // С учетом лимита 20000 токенов/минуту, используем чанки ~3000 токенов (~12000 символов)
        // Это позволит обработать ~6 чанков в минуту, оставляя запас на ответы
        let maxChunkSize = 12000

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
        print("📦 Текст разбит на \(chunks.count) чанков для суммаризации в Claude")
        progressCallback?("Разбито на \(chunks.count) чанков")

        // Последовательная суммаризация чанков
        summarizeChunksSequentially(chunks: chunks, apiKey: apiKey, progressCallback: progressCallback, completion: completion)
    }

    // Разбиение текста на чанки
    private func splitIntoChunks(_ text: String, maxChunkSize: Int) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        var chunks: [String] = []
        var currentChunk = ""

        for sentence in sentences {
            let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedSentence.isEmpty { continue }

            let sentenceWithPunctuation = trimmedSentence + "."

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

        if !currentChunk.isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return chunks
    }

    // Проверка и сброс лимита токенов
    private func checkAndResetRateLimit() {
        rateLimitQueue.sync {
            let now = Date()
            let timeElapsed = now.timeIntervalSince(minuteStartTime)

            if timeElapsed >= 60 {
                // Прошла минута, сбрасываем счетчик
                print("⏰ Сброс счетчика токенов: \(tokensUsedInCurrentMinute) токенов за последнюю минуту")
                tokensUsedInCurrentMinute = 0
                minuteStartTime = now
            }
        }
    }

    // Оценка количества токенов (примерно 4 символа = 1 токен)
    private func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }

    // Получение доступных токенов
    private func getAvailableTokens() -> Int {
        var available = 0
        rateLimitQueue.sync {
            available = maxTokensPerMinute - tokensUsedInCurrentMinute
        }
        return available
    }

    // Добавление использованных токенов
    private func addUsedTokens(_ tokens: Int) {
        rateLimitQueue.sync {
            tokensUsedInCurrentMinute += tokens
            print("📊 Использовано токенов: +\(tokens) (всего за минуту: \(tokensUsedInCurrentMinute)/\(maxTokensPerMinute))")
        }
    }

    // Последовательная суммаризация чанков с rate limiting
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
                if combinedSummary.count > 12000 {
                    print("📝 Финальная суммаризация объединенного результата в Claude")
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

            // Проверяем rate limit
            checkAndResetRateLimit()

            let estimatedInputTokens = estimateTokens(chunk) + estimateTokens("Summarize the following text concisely...") + 100
            let estimatedOutputTokens = 300 // Ожидаемый размер суммаризации
            let estimatedTotalTokens = estimatedInputTokens + estimatedOutputTokens

            let availableTokens = getAvailableTokens()

            if estimatedTotalTokens > availableTokens {
                // Не хватает токенов, нужно подождать
                let waitTime: TimeInterval = 60.0 // Ждем минуту для сброса лимита
                print("⏳ Достигнут лимит токенов (\(tokensUsedInCurrentMinute)/\(maxTokensPerMinute)). Ожидание \(Int(waitTime))с...")
                progressCallback?("Ожидание сброса лимита (\(Int(waitTime))с)")

                DispatchQueue.global().asyncAfter(deadline: .now() + waitTime) {
                    // После ожидания сбрасываем счетчик и продолжаем
                    self.rateLimitQueue.sync {
                        self.tokensUsedInCurrentMinute = 0
                        self.minuteStartTime = Date()
                    }
                    summarizeNextChunk()
                }
                return
            }

            print("📄 Суммаризация чанка \(currentIndex + 1)/\(chunks.count) в Claude (оценка: ~\(estimatedTotalTokens) токенов)")
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
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            completion(.failure(NSError(domain: "ClaudeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 60.0

        let summarizationPrompt: String
        if isFinalSummary {
            summarizationPrompt = """
            Create a final comprehensive summary by combining the following partial summaries.
            Keep all important information and write in the same language as the original text.
            Make the summary concise but informative:

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
            "model": "claude-3-7-sonnet-20250219",
            "max_tokens": 1000,
            "temperature": 0.3,
            "messages": [
                [
                    "role": "user",
                    "content": summarizationPrompt
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
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "ClaudeService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Нет данных"])))
                return
            }

            // Проверяем HTTP статус
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Claude Summarization HTTP Status: \(httpResponse.statusCode)")

                if httpResponse.statusCode >= 400 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Claude API Error Response: \(responseString)")
                        completion(.failure(NSError(domain: "ClaudeService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ошибка суммаризации (\(httpResponse.statusCode)): \(responseString)"])))
                    } else {
                        completion(.failure(NSError(domain: "ClaudeService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ошибка суммаризации: \(httpResponse.statusCode)"])))
                    }
                    return
                }
            }

            // Парсим ответ
            do {
                let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)

                // Учитываем использованные токены из ответа API
                if let usage = claudeResponse.usage {
                    let totalTokens = usage.input_tokens + usage.output_tokens
                    self.addUsedTokens(totalTokens)
                    print("✅ API вернул usage: input=\(usage.input_tokens), output=\(usage.output_tokens), total=\(totalTokens)")
                }

                if let firstContent = claudeResponse.content.first {
                    let summarizedText = firstContent.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(.success(summarizedText))
                    return
                }

                completion(.failure(NSError(domain: "ClaudeService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Пустой ответ при суммаризации"])))
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    completion(.failure(NSError(domain: "ClaudeService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Ошибка парсинга суммаризации: \(error.localizedDescription)\nОтвет: \(responseString)"])))
                } else {
                    completion(.failure(NSError(domain: "ClaudeService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Не удалось распарсить ответ суммаризации: \(error.localizedDescription)"])))
                }
            }
        }.resume()
    }
}
