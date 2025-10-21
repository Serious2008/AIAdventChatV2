//
//  HistoryCompressionService.swift
//  AIAdventChatV2
//
//  Service for compressing chat history using AI-generated summaries
//

import Foundation

class HistoryCompressionService {
    private let claudeService: ClaudeService
    private let settings: Settings

    // Configuration
    var compressionThreshold: Int = 10 // Compress every N messages
    var recentMessagesToKeep: Int = 5  // Keep last N messages uncompressed

    init(claudeService: ClaudeService, settings: Settings) {
        self.claudeService = claudeService
        self.settings = settings
    }

    /// Check if compression should be triggered
    func shouldCompress(messageCount: Int) -> Bool {
        return messageCount >= compressionThreshold + recentMessagesToKeep
    }

    /// Compress a batch of messages into a summary
    func compressMessages(_ messages: [Message]) async throws -> ConversationSummary {
        guard !messages.isEmpty else {
            throw CompressionError.emptyMessageList
        }

        // Filter out system messages
        let contentMessages = messages.filter { !$0.isSystemMessage }

        guard !contentMessages.isEmpty else {
            throw CompressionError.noContentToCompress
        }

        // Build conversation text for summarization
        let conversationText = buildConversationText(from: contentMessages)

        // Estimate original tokens
        let originalTokens = estimateTokens(for: conversationText)

        // Generate summary using Claude
        let summary = try await generateSummary(for: conversationText)

        // Estimate summary tokens
        let summaryTokens = estimateTokens(for: summary)

        // Get time range
        let startDate = contentMessages.first?.timestamp ?? Date()
        let endDate = contentMessages.last?.timestamp ?? Date()

        return ConversationSummary(
            summary: summary,
            originalMessagesCount: contentMessages.count,
            originalTokensEstimate: originalTokens,
            summaryTokensEstimate: summaryTokens,
            startDate: startDate,
            endDate: endDate
        )
    }

    /// Compress conversation history intelligently
    func compressHistory(
        _ history: CompressedConversationHistory,
        allMessages: [Message]
    ) async throws -> CompressedConversationHistory {
        guard shouldCompress(messageCount: allMessages.count) else {
            return CompressedConversationHistory(
                summaries: history.summaries,
                recentMessages: allMessages
            )
        }

        // Calculate how many messages to compress
        let totalMessages = allMessages.count
        let messagesToCompress = totalMessages - recentMessagesToKeep

        guard messagesToCompress > 0 else {
            return CompressedConversationHistory(
                summaries: history.summaries,
                recentMessages: allMessages
            )
        }

        // Split messages into compression batch and recent messages
        let batchToCompress = Array(allMessages.prefix(messagesToCompress))
        let recentMessages = Array(allMessages.suffix(recentMessagesToKeep))

        // Generate new summary for the batch
        let newSummary = try await compressMessages(batchToCompress)

        // Create new compressed history
        var newSummaries = history.summaries
        newSummaries.append(newSummary)

        return CompressedConversationHistory(
            summaries: newSummaries,
            recentMessages: recentMessages
        )
    }

    /// Build conversation text from messages
    private func buildConversationText(from messages: [Message]) -> String {
        var text = ""

        for message in messages {
            let role = message.isFromUser ? "User" : "Assistant"
            text += "\(role): \(message.content)\n\n"
        }

        return text
    }

    /// Generate summary using Claude API
    private func generateSummary(for conversationText: String) async throws -> String {
        let systemPrompt = """
        You are an AI assistant tasked with creating concise summaries of conversation segments.
        Your goal is to preserve all critical information while reducing token usage.

        Rules for summarization:
        1. Preserve key facts, decisions, and conclusions
        2. Maintain context about what was discussed
        3. Keep technical details, code snippets, and specific requirements
        4. Note any unresolved questions or pending tasks
        5. Use compact, information-dense language
        6. Avoid redundancy and pleasantries

        Format your summary as a coherent paragraph or structured list, depending on content complexity.
        """

        let userMessage = """
        Please summarize the following conversation segment, preserving all important information:

        \(conversationText)

        Summary:
        """

        // Build minimal message array for summarization
        let messagesArray: [[String: String]] = [
            ["role": "user", "content": userMessage]
        ]

        // Prepare request
        let requestBody: [String: Any] = [
            "model": "claude-3-7-sonnet-20250219",
            "max_tokens": 1000,
            "temperature": 0.3, // Lower temperature for more focused summaries
            "system": systemPrompt,
            "messages": messagesArray
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw CompressionError.invalidRequest
        }

        // Make API request
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw CompressionError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(settings.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CompressionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CompressionError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw CompressionError.parseError
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Simple token estimation (approximation: 1 token ≈ 4 characters)
    private func estimateTokens(for text: String) -> Int {
        return max(1, text.count / 4)
    }
}

// MARK: - Compression Errors

enum CompressionError: LocalizedError {
    case emptyMessageList
    case noContentToCompress
    case invalidRequest
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .emptyMessageList:
            return "Cannot compress an empty message list"
        case .noContentToCompress:
            return "No content messages found to compress"
        case .invalidRequest:
            return "Failed to create compression request"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid API response"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .parseError:
            return "Failed to parse summary response"
        }
    }
}
