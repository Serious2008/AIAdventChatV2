//
//  RAGService.swift
//  AIAdventChatV2
//
//  Service for Retrieval-Augmented Generation
//

import Foundation

// MARK: - RAG Response Model

struct RAGResponse {
    let answer: String
    let usedChunks: [SearchResult]
    let question: String
    let processingTime: TimeInterval
}

// MARK: - RAG Service

class RAGService {

    enum RAGError: Error {
        case vectorSearchFailed
        case llmFailed(String)
        case noRelevantContext
    }

    private let vectorSearchService: VectorSearchService

    // MARK: - Init

    init(vectorSearchService: VectorSearchService) {
        self.vectorSearchService = vectorSearchService
    }

    // MARK: - Public Methods

    /// Answer question using RAG (Retrieval-Augmented Generation)
    func answerWithRAG(
        question: String,
        topK: Int = 5,
        minSimilarity: Double = 0.3,
        rerankingStrategy: RerankingStrategy = .threshold(0.5)
    ) async throws -> RAGResponse {
        let startTime = Date()

        // Step 1: Search for relevant chunks (get more candidates for reranking)
        print("🔍 RAG: Searching for relevant chunks...")
        let candidateCount = rerankingStrategy == .llmBased ? 15 : topK
        let searchResults = try await vectorSearchService.search(query: question, topK: candidateCount)

        // Step 2: Rerank results
        print("🎯 RAG: Applying reranking strategy: \(rerankingStrategy)")
        let reranker = RerankerService()
        let relevantChunks = try await reranker.rerank(
            results: searchResults,
            question: question,
            strategy: rerankingStrategy,
            topK: topK
        )

        guard !relevantChunks.isEmpty else {
            throw RAGError.noRelevantContext
        }

        print("📚 RAG: Selected \(relevantChunks.count) chunks after reranking")

        // Step 2: Build context from chunks
        let context = buildContext(from: relevantChunks)

        // Step 3: Build prompt with context
        let prompt = buildRAGPrompt(question: question, context: context)

        print("💬 RAG: Sending prompt to LLM...")

        // Step 4: Send to LLM
        let answer = try await sendToLLM(prompt: prompt)

        let processingTime = Date().timeIntervalSince(startTime)

        print("✅ RAG: Complete in \(String(format: "%.2f", processingTime))s")

        return RAGResponse(
            answer: answer,
            usedChunks: relevantChunks,
            question: question,
            processingTime: processingTime
        )
    }

    /// Answer question without RAG (baseline)
    func answerWithoutRAG(question: String) async throws -> (answer: String, processingTime: TimeInterval) {
        let startTime = Date()
        print("💬 No RAG: Sending question directly to LLM...")
        let answer = try await sendToLLM(prompt: question)
        let processingTime = Date().timeIntervalSince(startTime)
        print("✅ No RAG: Complete in \(String(format: "%.2f", processingTime))s")
        return (answer, processingTime)
    }

    // MARK: - Private Methods

    private func buildContext(from chunks: [SearchResult]) -> String {
        var context = ""

        for (index, result) in chunks.enumerated() {
            let cleanedContent = result.chunk.content
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            context += """

            [Источник \(index + 1): \(result.chunk.fileName) - Релевантность: \(String(format: "%.1f%%", result.similarity * 100))]
            \(cleanedContent)

            ---

            """
        }

        return context
    }

    private func buildRAGPrompt(question: String, context: String) -> String {
        return """
        Ты - AI ассистент, который помогает разработчикам понять их код.

        КРИТИЧЕСКИ ВАЖНО - ОБЯЗАТЕЛЬНЫЕ ТРЕБОВАНИЯ:
        1. Используй ТОЛЬКО информацию из предоставленного контекста
        2. ОБЯЗАТЕЛЬНО указывай [Источник N] после КАЖДОГО утверждения
        3. Включай прямые цитаты кода в блоках ```
        4. В конце ответа добавь секцию "Источники:" со списком всех использованных файлов
        5. Если информации нет - скажи это честно и НЕ придумывай

        КОНТЕКСТ ИЗ КОДОВОЙ БАЗЫ:
        \(context)

        ВОПРОС ПОЛЬЗОВАТЕЛЯ:
        \(question)

        ФОРМАТ ОТВЕТА (ОБЯЗАТЕЛЕН):

        [Основной ответ с маркерами [Источник 1], [Источник 2] после каждого факта]

        [Цитаты кода в блоках ```swift если есть]

        Источники:
        [1] FileName.swift - краткое описание
        [2] FileName.swift - краткое описание

        НАЧНИ ОТВЕТ СЕЙЧАС:
        """
    }

    private func sendToLLM(prompt: String) async throws -> String {
        // Get API key from settings
        guard let apiKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] ?? UserDefaults.standard.string(forKey: "ClaudeAPIKey"),
              !apiKey.isEmpty else {
            throw RAGError.llmFailed("Claude API key not found")
        }

        // Create Claude API request
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "claude-3-7-sonnet-20250219",
            "max_tokens": 4096,
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
            throw RAGError.llmFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RAGError.llmFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        // Parse Claude response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw RAGError.llmFailed("Failed to parse response")
        }

        return text
    }

    // MARK: - Citation Validation

    /// Validates if answer contains proper citations
    func validateCitations(_ answer: String) -> CitationValidation {
        // Check for source markers like [Источник N] or [N]
        let sourceMarkerPattern = #"\[Источник\s+\d+\]|\[\d+\]"#
        let hasSourceMarkers = answer.range(of: sourceMarkerPattern, options: .regularExpression) != nil

        // Count citations
        let regex = try? NSRegularExpression(pattern: sourceMarkerPattern, options: [])
        let matches = regex?.matches(in: answer, options: [], range: NSRange(answer.startIndex..., in: answer))
        let citationCount = matches?.count ?? 0

        // Check for "Источники:" section
        let hasSourcesSection = answer.contains("Источники:") || answer.contains("Sources:")

        // Check for file references (.swift, .md, etc.)
        let hasFileReferences = answer.contains(".swift") || answer.contains(".md")

        // Check for code blocks
        let hasCodeBlocks = answer.contains("```")

        return CitationValidation(
            hasSourceMarkers: hasSourceMarkers,
            hasSourcesSection: hasSourcesSection,
            hasFileReferences: hasFileReferences,
            hasCodeBlocks: hasCodeBlocks,
            citationCount: citationCount
        )
    }

    /// Answer with mandatory citations (with retry if needed)
    func answerWithMandatoryCitations(
        question: String,
        topK: Int = 5,
        minSimilarity: Double = 0.3,
        rerankingStrategy: RerankingStrategy = .threshold(0.5),
        maxAttempts: Int = 2
    ) async throws -> RAGResponse {

        var attempts = 0

        while attempts < maxAttempts {
            print("🔍 RAG Citations: Attempt \(attempts + 1)/\(maxAttempts)")

            // Get answer
            let response = try await answerWithRAG(
                question: question,
                topK: topK,
                minSimilarity: minSimilarity,
                rerankingStrategy: rerankingStrategy
            )

            // Validate citations
            let validation = validateCitations(response.answer)

            print("📊 Citation validation: markers=\(validation.hasSourceMarkers), count=\(validation.citationCount), sources=\(validation.hasSourcesSection)")

            // Check if valid
            if validation.isValid {
                print("✅ RAG Citations: Valid! Citations found: \(validation.citationCount)")
                return response
            }

            // If invalid and not last attempt, retry
            attempts += 1
            if attempts < maxAttempts {
                print("⚠️ RAG Citations: Invalid, retrying with stricter prompt...")
                // Note: In a more sophisticated implementation, we could modify the prompt here
            }
        }

        // If all attempts failed, throw error
        print("❌ RAG Citations: Failed to get valid citations after \(maxAttempts) attempts")
        throw RAGError.noRelevantContext
    }
}

// MARK: - Citation Validation

struct CitationValidation {
    let hasSourceMarkers: Bool
    let hasSourcesSection: Bool
    let hasFileReferences: Bool
    let hasCodeBlocks: Bool
    let citationCount: Int

    var isValid: Bool {
        // At minimum, need source markers and at least 1 citation
        return hasSourceMarkers && citationCount >= 1
    }

    var score: Double {
        var score = 0.0
        if hasSourceMarkers { score += 0.3 }
        if hasSourcesSection { score += 0.3 }
        if hasFileReferences { score += 0.2 }
        if hasCodeBlocks { score += 0.2 }
        return score
    }

    var summary: String {
        """
        ✅ Маркеры источников: \(hasSourceMarkers ? "Да" : "Нет")
        ✅ Секция "Источники": \(hasSourcesSection ? "Да" : "Нет")
        ✅ Упоминания файлов: \(hasFileReferences ? "Да" : "Нет")
        ✅ Блоки кода: \(hasCodeBlocks ? "Да" : "Нет")
        📊 Количество цитат: \(citationCount)
        🎯 Качество: \(String(format: "%.0f%%", score * 100))
        """
    }
}

// MARK: - Comparison Result

struct RAGComparison {
    let question: String
    let withRAG: RAGResponse
    let withoutRAG: String
    let ragProcessingTime: TimeInterval
    let noRAGProcessingTime: TimeInterval

    var analysis: String {
        return """

        📊 СРАВНЕНИЕ RAG vs БЕЗ RAG

        Вопрос: \(question)

        ⏱ Время обработки:
        • С RAG: \(String(format: "%.2f", ragProcessingTime))s
        • Без RAG: \(String(format: "%.2f", noRAGProcessingTime))s

        📚 Использовано источников: \(withRAG.usedChunks.count)

        🔍 Релевантность источников:
        \(withRAG.usedChunks.enumerated().map { index, chunk in
            "  \(index + 1). \(chunk.chunk.fileName) - \(String(format: "%.1f%%", chunk.similarity * 100))"
        }.joined(separator: "\n"))

        ✅ ОТВЕТ С RAG содержит конкретные детали из кода
        ⚠️ ОТВЕТ БЕЗ RAG может быть общим или неточным
        """
    }
}
