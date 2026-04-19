//
//  RerankerService.swift
//  AIAdventChatV2
//
//  Service for reranking search results to improve relevance
//

import Foundation

// MARK: - Reranking Strategy

enum RerankingStrategy: Equatable {
    case none                           // No reranking
    case threshold(Double)              // Simple threshold filtering
    case adaptive                       // Adaptive threshold based on score distribution
    case llmBased                       // Use LLM to evaluate relevance

    var description: String {
        switch self {
        case .none:
            return "Без фильтрации"
        case .threshold(let value):
            return "Threshold (\(Int(value * 100))%)"
        case .adaptive:
            return "Adaptive"
        case .llmBased:
            return "LLM-based"
        }
    }
}

// MARK: - Reranked Result

struct RerankedResult {
    let original: SearchResult
    let rerankScore: Double?  // New score from reranker (nil if not reranked)
    let filterReason: String? // Why filtered out (if any)
}

// MARK: - Reranker Service

class RerankerService {

    enum RerankerError: Error {
        case noResultsAfterFiltering
        case rerankingFailed(String)
    }

    // MARK: - Public Methods

    /// Rerank search results using specified strategy
    func rerank(
        results: [SearchResult],
        question: String,
        strategy: RerankingStrategy,
        topK: Int = 5
    ) async throws -> [SearchResult] {

        switch strategy {
        case .none:
            return Array(results.prefix(topK))

        case .threshold(let minSimilarity):
            return try rerankWithThreshold(
                results: results,
                minSimilarity: minSimilarity,
                topK: topK
            )

        case .adaptive:
            return try rerankAdaptive(
                results: results,
                topK: topK
            )

        case .llmBased:
            return try await rerankWithLLM(
                results: results,
                question: question,
                topK: topK
            )
        }
    }

    // MARK: - Threshold Reranking

    private func rerankWithThreshold(
        results: [SearchResult],
        minSimilarity: Double,
        topK: Int
    ) throws -> [SearchResult] {

        print("🔍 Reranker: Applying threshold filter (min: \(String(format: "%.1f%%", minSimilarity * 100)))")

        let filtered = results.filter { $0.similarity >= minSimilarity }

        if filtered.isEmpty {
            // Fallback: если ничего не прошло порог, берём топ-K с предупреждением
            let highestScore = results.first?.similarity ?? 0
            print("⚠️ Reranker: No results passed threshold (\(String(format: "%.1f%%", minSimilarity * 100))). Highest score: \(String(format: "%.1f%%", highestScore * 100))")
            print("⚠️ Reranker: Falling back to top-\(topK) results without filtering")
            return Array(results.prefix(topK))
        }

        let final = Array(filtered.prefix(topK))

        print("✅ Reranker: \(final.count)/\(results.count) results passed threshold")

        return final
    }

    // MARK: - Adaptive Reranking

    private func rerankAdaptive(
        results: [SearchResult],
        topK: Int
    ) throws -> [SearchResult] {

        print("🔍 Reranker: Using adaptive threshold")

        guard !results.isEmpty else {
            throw RerankerError.noResultsAfterFiltering
        }

        // Calculate statistics
        let similarities = results.map { $0.similarity }
        let mean = similarities.reduce(0, +) / Double(similarities.count)
        let variance = similarities.map { pow($0 - mean, 2) }.reduce(0, +) / Double(similarities.count)
        let stdDev = sqrt(variance)

        // Adaptive threshold: mean - 0.5 * stdDev
        // This keeps results within reasonable range of the average
        let adaptiveThreshold = max(0.3, mean - 0.5 * stdDev)

        print("📊 Reranker: Mean=\(String(format: "%.2f", mean)), StdDev=\(String(format: "%.2f", stdDev))")
        print("📊 Reranker: Adaptive threshold: \(String(format: "%.1f%%", adaptiveThreshold * 100))")

        let filtered = results.filter { $0.similarity >= adaptiveThreshold }

        guard !filtered.isEmpty else {
            // If adaptive threshold filters everything, fall back to top results
            print("⚠️ Reranker: Adaptive filter too strict, using top \(topK) results")
            return Array(results.prefix(topK))
        }

        let final = Array(filtered.prefix(topK))

        print("✅ Reranker: \(final.count)/\(results.count) results passed adaptive filter")

        return final
    }

    // MARK: - LLM-based Reranking

    private func rerankWithLLM(
        results: [SearchResult],
        question: String,
        topK: Int
    ) async throws -> [SearchResult] {

        print("🔍 Reranker: Using LLM-based reranking")

        // Take top 10-15 candidates for reranking (to save tokens)
        let candidates = Array(results.prefix(15))

        // Build prompt for LLM to evaluate relevance
        let prompt = buildRerankingPrompt(question: question, results: candidates)

        // Get API key
        guard let apiKey = UserDefaults.standard.string(forKey: "ClaudeAPIKey"), !apiKey.isEmpty else {
            throw RerankerError.rerankingFailed("API key not found")
        }

        // Call LLM
        let response = try await sendLLMRequest(prompt: prompt, apiKey: apiKey)

        // Parse scores
        let scores = parseRerankingScores(response: response, count: candidates.count)

        // Create scored results
        var scoredResults: [(result: SearchResult, score: Double)] = []
        for (index, result) in candidates.enumerated() {
            let llmScore = scores[safe: index] ?? 0.0
            // Combine original similarity with LLM score (weighted average)
            let finalScore = 0.4 * result.similarity + 0.6 * llmScore
            scoredResults.append((result, finalScore))
        }

        // Sort by final score and take top-K
        scoredResults.sort { $0.score > $1.score }
        let final = scoredResults.prefix(topK).map { $0.result }

        print("✅ Reranker: LLM reranked \(candidates.count) → \(final.count) results")

        return final
    }

    // MARK: - Helper Methods

    private func buildRerankingPrompt(question: String, results: [SearchResult]) -> String {
        var prompt = """
        Оцени релевантность каждого фрагмента кода для ответа на вопрос пользователя.

        ВОПРОС: \(question)

        ФРАГМЕНТЫ:

        """

        for (index, result) in results.enumerated() {
            let preview = String(result.chunk.content.prefix(300))
            prompt += """

            [\(index + 1)] Файл: \(result.chunk.fileName)
            Содержание: \(preview)...

            """
        }

        prompt += """

        ЗАДАНИЕ:
        Оцени каждый фрагмент по шкале от 0 до 10:
        - 0-3: Не релевантен (не помогает ответить на вопрос)
        - 4-6: Частично релевантен (косвенно связан)
        - 7-8: Релевантен (содержит полезную информацию)
        - 9-10: Очень релевантен (прямо отвечает на вопрос)

        Верни ТОЛЬКО массив чисел в формате JSON, например: [8, 3, 9, 2, 7]
        Порядок должен соответствовать порядку фрагментов.
        """

        return prompt
    }

    private func sendLLMRequest(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RerankerError.rerankingFailed("Invalid HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Reranker API Error (\(httpResponse.statusCode)): \(errorText)")
            throw RerankerError.rerankingFailed("HTTP \(httpResponse.statusCode): \(errorText)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            let jsonString = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("❌ Reranker: Failed to parse response. JSON: \(jsonString)")
            throw RerankerError.rerankingFailed("Failed to parse response")
        }

        print("✅ Reranker: LLM response received: \(text.prefix(100))...")
        return text
    }

    private func parseRerankingScores(response: String, count: Int) -> [Double] {
        // Try to extract JSON array from response
        // Response might be like: "Here are the scores: [8, 3, 9, 2, 7]"

        // Find JSON array pattern
        if let range = response.range(of: #"\[[\d\s,]+\]"#, options: .regularExpression) {
            let jsonString = String(response[range])

            if let data = jsonString.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [Int] {
                return array.map { min(10.0, max(0.0, Double($0))) / 10.0 } // Normalize to 0-1
            }
        }

        // Fallback: return decreasing scores based on original order
        print("⚠️ Reranker: Failed to parse LLM scores, using fallback")
        return (0..<count).map { 1.0 - (Double($0) * 0.05) }
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Reranking Comparison

struct RerankingComparison {
    let question: String
    let originalResults: [SearchResult]
    let noFilterResults: [SearchResult]
    let thresholdResults: [SearchResult]
    let adaptiveResults: [SearchResult]
    let llmResults: [SearchResult]?

    var summary: String {
        return """

        📊 СРАВНЕНИЕ RERANKING СТРАТЕГИЙ

        Вопрос: \(question)
        Исходных результатов: \(originalResults.count)

        1️⃣ Без фильтра: \(noFilterResults.count) результатов
           Мин. similarity: \(noFilterResults.last?.similarity ?? 0)

        2️⃣ Threshold (60%): \(thresholdResults.count) результатов
           Мин. similarity: \(thresholdResults.last?.similarity ?? 0)

        3️⃣ Adaptive: \(adaptiveResults.count) результатов
           Мин. similarity: \(adaptiveResults.last?.similarity ?? 0)

        \(llmResults.map { "4️⃣ LLM-based: \($0.count) результатов" } ?? "4️⃣ LLM-based: не использован")
        """
    }
}
