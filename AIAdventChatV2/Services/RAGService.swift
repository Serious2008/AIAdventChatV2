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
        minSimilarity: Double = 0.3
    ) async throws -> RAGResponse {
        let startTime = Date()

        // Step 1: Search for relevant chunks
        print("🔍 RAG: Searching for relevant chunks...")
        let searchResults = try await vectorSearchService.search(query: question, topK: topK)

        // Filter by minimum similarity
        let relevantChunks = searchResults.filter { $0.similarity >= minSimilarity }

        guard !relevantChunks.isEmpty else {
            throw RAGError.noRelevantContext
        }

        print("📚 RAG: Found \(relevantChunks.count) relevant chunks")

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
    func answerWithoutRAG(question: String) async throws -> String {
        print("💬 No RAG: Sending question directly to LLM...")
        return try await sendToLLM(prompt: question)
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

        Используй ТОЛЬКО информацию из предоставленного контекста для ответа на вопрос.
        Если в контексте нет информации для ответа, скажи это честно.
        Всегда указывай из какого источника ты взял информацию.

        КОНТЕКСТ ИЗ КОДОВОЙ БАЗЫ:
        \(context)

        ВОПРОС ПОЛЬЗОВАТЕЛЯ:
        \(question)

        ИНСТРУКЦИИ:
        1. Внимательно изучи предоставленный контекст
        2. Найди информацию, релевантную вопросу
        3. Дай точный ответ, основанный на контексте
        4. Укажи источники (номера источников в квадратных скобках)
        5. Если информации недостаточно - скажи об этом

        ОТВЕТ:
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
